import Foundation

func gwLog(_ msg: String) {
    let line = "[\(Date())] \(msg)\n"
    if let data = line.data(using: .utf8) {
        let url = URL(fileURLWithPath: "/tmp/ocm-gw.log")
        if FileManager.default.fileExists(atPath: url.path),
           let fh = try? FileHandle(forWritingTo: url) {
            fh.seekToEndOfFile(); fh.write(data); try? fh.close()
        } else {
            try? data.write(to: url)
        }
    }
    print(msg)
}

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
    let modelProvider: String
    let modelId: String?       // last-used model name (e.g. "claude-opus-4-6")
    let displayName: String?   // cleaned user/channel name
    let chatType: String       // "direct" | "group" | "cron"
    let lastActivityMs: Double // raw updatedAt timestamp for recency sorting
}

// MARK: - GatewayService

@MainActor
final class GatewayService: NSObject {

    static let shared = GatewayService()
    private override init() {}

    // MARK: - Callbacks (set by AppViewModel)

    var onAgentsUpdated:   (([GWAgent]) -> Void)?
    var onSessionsUpdated: (([GWSession]) -> Void)?
    var onSkillsUpdated:   (([SkillInfo]) -> Void)?
    var onUsageUpdated:      (([StatPoint]) -> Void)?
    var onAgentUsageUpdated: (([String: Int]) -> Void)?
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
        gwLog("[GatewayService] recv type=\(type ?? "?") event=\(frame["event"] ?? "-") method=\(frame["method"] ?? "-") ok=\(frame["ok"] ?? "-")")

        if type == "event" {
            let event   = frame["event"] as? String ?? ""
            let payload = frame["payload"] as? [String: Any] ?? [:]
            handleEvent(event: event, payload: payload)

        } else if type == "res", let id = frame["id"] as? String {
            let ok = frame["ok"] as? Bool ?? false
            if !ok { gwLog("[GatewayService] res FAILED frame=\(frame)") }
            guard let cont = pendingCalls.removeValue(forKey: id) else { return }
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
        let role   = "operator"
        let scopes = ["operator.read", "operator.write", "operator.admin",
                      "operator.approvals", "operator.pairing"]
        let identity = DeviceIdentity.shared

        guard let (sig, signedAt) = identity.sign(
            nonce:  nonce ?? "",
            token:  currentToken ?? "",
            role:   role,
            scopes: scopes
        ) else {
            gwLog("[GatewayService] Failed to sign device auth payload")
            handleDisconnect()
            return
        }

        gwLog("[GatewayService] sendConnect nonce=\(nonce ?? "nil") deviceId=\(identity.deviceId.prefix(16))... token=\(currentToken.map { String($0.prefix(8)) + "..." } ?? "nil")")

        let deviceBlock: [String: Any] = [
            "id":        identity.deviceId,
            "publicKey": identity.publicKeyBase64URL,
            "signature": sig,
            "signedAt":  signedAt,
            "nonce":     nonce ?? ""
        ]
        let params: [String: Any] = [
            "minProtocol": 3,
            "maxProtocol": 3,
            "client": [
                "id":          "openclaw-macos",
                "displayName": "OpenClaw Monitor",
                "version":     "1.0.0",
                "platform":    "macos",
                "mode":        "ui"
            ] as [String: Any],
            "role":      role,
            "scopes":    scopes,
            "caps":      [],
            "auth":      ["token": currentToken ?? ""] as [String: Any],
            "device":    deviceBlock,
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
            if let response {
                gwLog("[GatewayService] Handshake OK, payload keys: \(response.keys.sorted())")
                completeHandshake()
            } else {
                gwLog("[GatewayService] Auth failed — check gateway.auth.token in openclaw.json")
                handleDisconnect()
            }
        }
    }

    private func completeHandshake() {
        guard !handshakeDone else { return }
        handshakeDone = true
        isConnected   = true
        onConnected?()   // AppViewModel handles fetching via onConnected callback
    }

    func fetchUsage() async {
        guard let payload = await call(method: "sessions.usage") else {
            gwLog("[GatewayService] sessions.usage failed")
            return
        }
        let aggregates   = payload["aggregates"]   as? [String: Any] ?? [:]
        let daily        = aggregates["daily"]        as? [[String: Any]] ?? []
        let dailyLatency = aggregates["dailyLatency"] as? [[String: Any]] ?? []
        let modelDaily   = aggregates["modelDaily"]   as? [[String: Any]] ?? []
        let byAgent      = aggregates["byAgent"]      as? [[String: Any]] ?? []

        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.timeZone   = .current

        // date -> avgMs
        var latencyMap: [String: Int] = [:]
        for item in dailyLatency {
            guard let dateStr = item["date"] as? String else { continue }
            latencyMap[dateStr] = Int(anyDouble(item["avgMs"]))
        }
        // date -> [model: tokens]
        var modelMap: [String: [String: Int]] = [:]
        for item in modelDaily {
            guard let dateStr = item["date"] as? String,
                  let model   = item["model"] as? String,
                  !StatsCollector.excludedModelPrefixes.contains(where: { model.lowercased().contains($0) })
            else { continue }
            let tokens = item["tokens"] as? Int ?? 0
            modelMap[dateStr, default: [:]][model, default: 0] += tokens
        }

        let points: [StatPoint] = daily.compactMap { item in
            guard let dateStr = item["date"] as? String,
                  let date    = df.date(from: dateStr) else { return nil }
            return StatPoint(
                date:          date,
                tokens:        item["tokens"]   as? Int ?? 0,
                messages:      item["messages"] as? Int ?? 0,
                avgResponseMs: latencyMap[dateStr] ?? 0,
                byModel:       modelMap[dateStr] ?? [:]
            )
        }.sorted { $0.date < $1.date }

        // agentId -> totalTokens
        var agentTotals: [String: Int] = [:]
        for item in byAgent {
            guard let agentId = item["agentId"] as? String,
                  let totals  = item["totals"]  as? [String: Any],
                  let tokens  = totals["totalTokens"] as? Int else { continue }
            agentTotals[agentId] = tokens
        }

        gwLog("[GatewayService] usage: \(points.count) daily points, \(agentTotals.count) agents")
        onUsageUpdated?(points)
        onAgentUsageUpdated?(agentTotals)
    }

    /// Strips the " id:NNNN" suffix appended by the gateway: "Ken Shi id:8639178504" → "Ken Shi"
    private static func cleanDisplayName(_ raw: String) -> String {
        if let range = raw.range(of: #"\s+id:\d+$"#, options: .regularExpression) {
            return String(raw[raw.startIndex..<range.lowerBound])
        }
        return raw
    }

    private func anyDouble(_ v: Any?) -> Double {
        if let d = v as? Double { return d }
        if let s = v as? String { return Double(s) ?? 0 }
        if let i = v as? Int    { return Double(i) }
        return 0
    }

    func fetchSkillsStatus() async {
        guard let payload = await call(method: "skills.status") else {
            gwLog("[GatewayService] skills.status failed (nil response)")
            return
        }
        let rawSkills = (payload["skills"] as? NSArray)?.compactMap { $0 as? [String: Any] }
                     ?? payload["skills"] as? [[String: Any]]
                     ?? []
        gwLog("[GatewayService] skills count: \(rawSkills.count)")
        let skills: [SkillInfo] = rawSkills.compactMap { item in
            guard let key = item["skillKey"] as? String else { return nil }
            let name     = item["name"]        as? String ?? key
            let desc     = item["description"] as? String ?? ""
            let emoji    = item["emoji"]       as? String
            let eligible = item["eligible"]    as? Int ?? 0
            let disabled = item["disabled"]    as? Int ?? 0
            let source   = item["source"]      as? String ?? ""
            let skillType: SkillType
            switch source {
            case "openclaw-bundled": skillType = .builtin
            case "managed":         skillType = .extended
            default:                skillType = .custom
            }
            return SkillInfo(
                id:          key,
                name:        name,
                description: desc,
                type:        skillType,
                isEnabled:   eligible == 1 && disabled == 0,
                isEligible:  eligible == 1,
                emoji:       emoji
            )
        }
        onSkillsUpdated?(skills)
    }

    // MARK: - RPC call

    /// Lightweight gateway ping — returns true if WebSocket is alive and responds.
    func ping() async -> Bool {
        await call(method: "agents.list") != nil
    }

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
            if let error { gwLog("[GatewayService] send error: \(error)") }
        }
    }

    private func failAllPending() {
        let pending = pendingCalls
        pendingCalls = [:]
        for (_, cont) in pending { cont.resume(returning: nil) }
    }

    // MARK: - Data fetchers

    func fetchAgents() async {
        guard let payload = await call(method: "agents.list") else {
            gwLog("[GatewayService] agents.list failed (nil response)")
            return
        }
        let rawList = payload["agents"] as? [[String: Any]] ?? []
        gwLog("[GatewayService] agents count: \(rawList.count)")
        let agents: [GWAgent] = rawList.compactMap { item in
            guard let id = item["id"] as? String else { return nil }
            // Gateway returns minimal agent data; name/emoji come from config
            let identity = item["identity"] as? [String: Any]
            return GWAgent(
                id:    id,
                name:  identity?["name"] as? String ?? id,
                emoji: identity?["emoji"] as? String ?? "🤖"
            )
        }
        onAgentsUpdated?(agents)
    }

    func fetchSessions() async {
        guard let payload = await call(method: "sessions.list", params: ["limit": 100]) else {
            gwLog("[GatewayService] sessions.list failed (nil response)")
            return
        }
        let rawList = payload["sessions"] as? [[String: Any]] ?? []
        gwLog("[GatewayService] sessions count: \(rawList.count)")
        let sessions: [GWSession] = rawList.compactMap { item in
            guard let key = item["key"] as? String else { return nil }
            // key: "agent:{agentId}:…"
            let parts     = key.split(separator: ":")
            let agentId   = parts.count >= 2 ? String(parts[1]) : key
            let tokens    = item["totalTokens"] as? Int ?? 0
            let platform  = item["lastChannel"] as? String ?? "unknown"
            let updatedMs = item["updatedAt"] as? Double ?? 0
            let lastAct   = updatedMs > 0 ? Date(timeIntervalSince1970: updatedMs / 1000) : Date()
            let status    = (item["abortedLastRun"] as? Int ?? 0) > 0 ? "idle" : "active"
            let modelProvider = item["modelProvider"] as? String ?? ""
            let modelId   = item["modelId"] as? String ?? item["model"] as? String
            let chatType  = item["chatType"] as? String ?? item["kind"] as? String ?? "direct"
            // "Ken Shi id:8639178504" → "Ken Shi"
            let rawName   = item["displayName"] as? String
            let cleanName = rawName.map { GatewayService.cleanDisplayName($0) }
            return GWSession(key: key, agentId: agentId,
                             status: status,
                             tokens: tokens, messageCount: 0,
                             platform: platform, lastActivity: lastAct,
                             modelProvider: modelProvider,
                             modelId: modelId,
                             displayName: cleanName, chatType: chatType,
                             lastActivityMs: updatedMs)
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
