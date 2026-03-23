import Foundation

// MARK: - Public result types

struct GWAgent {
    let id: String
    let name: String
    let emoji: String
}

struct GWSession {
    let key: String
    let agentId: String
    let status: String
    let tokens: Int
    let messageCount: Int
    let platform: String
    let lastActivity: Date
}

// MARK: - GatewayService

@MainActor
final class GatewayService: NSObject {

    static let shared = GatewayService()
    private override init() {}

    // MARK: - Callbacks (set by AppViewModel)

    var onAgentsUpdated:   (([GWAgent]) -> Void)?
    var onSessionsUpdated: (([GWSession]) -> Void)?
    var onConnected:       (() -> Void)?
    var onDisconnected:    (() -> Void)?

    private(set) var isConnected = false

    // MARK: - Private state

    private var wsTask: URLSessionWebSocketTask?
    private var wsSession: URLSession?
    private var pendingCalls: [String: CheckedContinuation<[String: Any]?, Never>] = [:]
    private var handshakeDone = false
    private var reconnectTask: Task<Void, Never>?
    private var currentPort  = 18789
    private var currentToken: String?

    // MARK: - Public API

    func connect(port: Int, token: String?) {
        currentPort  = port
        currentToken = token
        reconnectTask?.cancel()
        reconnectTask = nil
        closeSocket()
        openSocket()
    }

    func disconnect() {
        reconnectTask?.cancel()
        reconnectTask = nil
        closeSocket()
    }

    // MARK: - Socket lifecycle

    private func openSocket() {
        guard let url = URL(string: "ws://127.0.0.1:\(currentPort)/") else { return }
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        let session = URLSession(configuration: config, delegate: self,
                                 delegateQueue: .main)
        wsSession = session
        let task = session.webSocketTask(with: url)
        wsTask = task
        task.resume()
        armReceive()
    }

    private func closeSocket() {
        wsTask?.cancel(with: .goingAway, reason: nil)
        wsTask = nil
        isConnected    = false
        handshakeDone  = false
        failAllPending()
    }

    private func armReceive() {
        wsTask?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure:
                self.handleDisconnect()
            case .success(let message):
                let text: String?
                switch message {
                case .string(let s): text = s
                case .data(let d):   text = String(data: d, encoding: .utf8)
                @unknown default:    text = nil
                }
                if let text, let frame = self.parseFrame(text) {
                    self.dispatch(frame: frame)
                }
                self.armReceive()   // arm next receive
            }
        }
    }

    private func handleDisconnect() {
        let wasConnected = isConnected || handshakeDone
        closeSocket()
        if wasConnected { onDisconnected?() }
        scheduleReconnect()
    }

    private func scheduleReconnect() {
        reconnectTask?.cancel()
        reconnectTask = Task {
            try? await Task.sleep(for: .seconds(10))
            guard !Task.isCancelled else { return }
            openSocket()
        }
    }

    // MARK: - Frame dispatch

    private func parseFrame(_ text: String) -> [String: Any]? {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return json
    }

    private func dispatch(frame: [String: Any]) {
        let type = frame["type"] as? String

        if type == "event" {
            let event   = frame["event"] as? String ?? ""
            let payload = frame["payload"] as? [String: Any] ?? [:]
            handleEvent(event: event, payload: payload)

        } else if type == "res", let id = frame["id"] as? String {
            guard let cont = pendingCalls.removeValue(forKey: id) else { return }
            let ok = frame["ok"] as? Bool ?? false
            cont.resume(returning: ok ? (frame["payload"] as? [String: Any] ?? [:]) : nil)
        }
    }

    private func handleEvent(event: String, payload: [String: Any]) {
        switch event {
        case "connect.challenge":
            sendConnect(nonce: payload["nonce"] as? String)
        default:
            break
        }
    }

    // MARK: - Handshake

    private func sendConnect(nonce: String?) {
        let reqId  = UUID().uuidString
        let params: [String: Any] = [
            "minProtocol": 3,
            "maxProtocol": 3,
            "client": [
                "id":          "openclaw-macos-monitor",
                "displayName": "OpenClaw Monitor",
                "version":     "1.0.0",
                "platform":    "macos",
                "mode":        "operator"
            ] as [String: Any],
            "role":      "operator",
            "scopes":    ["operator.read"],
            "caps":      [],
            "auth":      ["token": currentToken ?? ""] as [String: Any],
            "locale":    Locale.current.identifier,
            "userAgent": "openclaw-monitor/1.0.0"
        ]
        let frame: [String: Any] = [
            "type": "req", "id": reqId, "method": "connect", "params": params
        ]

        Task {
            let response = await withCheckedContinuation {
                (cont: CheckedContinuation<[String: Any]?, Never>) in
                pendingCalls[reqId] = cont
                sendFrame(frame)
            }
            if response != nil {
                completeHandshake()
            } else {
                print("[GatewayService] Auth failed — check gateway.auth.token in openclaw.json")
                handleDisconnect()
            }
        }
    }

    private func completeHandshake() {
        guard !handshakeDone else { return }
        handshakeDone = true
        isConnected   = true
        onConnected?()
        Task { await fetchAgents() }
        Task { await fetchSessions() }
    }

    // MARK: - RPC call

    private func call(method: String, params: [String: Any] = [:]) async -> [String: Any]? {
        guard isConnected else { return nil }
        let reqId = UUID().uuidString
        let frame: [String: Any] = [
            "type": "req", "id": reqId, "method": method, "params": params
        ]
        return await withCheckedContinuation { cont in
            pendingCalls[reqId] = cont
            sendFrame(frame)
        }
    }

    private func sendFrame(_ dict: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let text = String(data: data, encoding: .utf8) else { return }
        wsTask?.send(.string(text)) { error in
            if let error { print("[GatewayService] send error: \(error)") }
        }
    }

    private func failAllPending() {
        let pending = pendingCalls
        pendingCalls = [:]
        for (_, cont) in pending { cont.resume(returning: nil) }
    }

    // MARK: - Data fetchers

    func fetchAgents() async {
        guard let payload = await call(method: "agents.list") else { return }
        let rawList = payload["agents"] as? [[String: Any]] ?? []
        let agents: [GWAgent] = rawList.compactMap { item in
            guard let id = item["id"] as? String else { return nil }
            let identity = item["identity"] as? [String: Any]
            return GWAgent(
                id:    id,
                name:  identity?["name"]  as? String ?? id,
                emoji: identity?["emoji"] as? String ?? "🤖"
            )
        }
        onAgentsUpdated?(agents)
    }

    func fetchSessions() async {
        guard let payload = await call(method: "sessions.list", params: ["limit": 100]) else { return }
        let rawList = payload["sessions"] as? [[String: Any]] ?? []
        let isoFmt  = ISO8601DateFormatter()
        let sessions: [GWSession] = rawList.compactMap { item in
            guard let key     = (item["key"] ?? item["id"]) as? String,
                  let agentId = item["agentId"] as? String else { return nil }
            let usage       = item["usage"] as? [String: Any]
            let tokens      = usage?["tokens"]  as? Int ?? item["tokenCount"]  as? Int ?? 0
            let msgCount    = item["messageCount"] as? Int ?? item["messages"] as? Int ?? 0
            let platform    = item["platform"] as? String ?? "unknown"
            let lastAct     = (item["lastActivity"] as? String).flatMap { isoFmt.date(from: $0) } ?? Date()
            return GWSession(key: key, agentId: agentId,
                             status: item["status"] as? String ?? "idle",
                             tokens: tokens, messageCount: msgCount,
                             platform: platform, lastActivity: lastAct)
        }
        onSessionsUpdated?(sessions)
    }
}

// MARK: - URLSessionWebSocketDelegate

extension GatewayService: URLSessionWebSocketDelegate {
    nonisolated func urlSession(_ session: URLSession,
                                webSocketTask: URLSessionWebSocketTask,
                                didOpenWithProtocol protocol: String?) {
        // Wait for connect.challenge event from gateway
    }

    nonisolated func urlSession(_ session: URLSession,
                                webSocketTask: URLSessionWebSocketTask,
                                didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
                                reason: Data?) {
        Task { @MainActor [weak self] in self?.handleDisconnect() }
    }
}
