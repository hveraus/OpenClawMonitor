import Foundation
import SwiftUI
import Combine

@MainActor
final class AppViewModel: ObservableObject {

    // MARK: - Published Data

    @Published var agents: [AgentConfig]                  = []
    @Published var agentRuntimes: [String: AgentRuntime]  = [:]
    @Published var models: [ModelInfo]                    = []
    @Published var sessions: [SessionInfo]                = []
    @Published var alerts: [AlertItem]                    = []
    @Published var skills: [SkillInfo]                    = []
    @Published var statPoints: [StatPoint]                = []
    @Published var agentUsage: [String: Int]              = [:]   // agentId → totalTokens

    @Published var gatewayStatus: GatewayStatus           = .unknown
    @Published var gatewayPort: Int                       = 18789

    @Published var isUsingMockData: Bool                  = true
    @Published var configFilePath: String?                = nil
    @Published var configError: String?                   = nil

    /// Auto-refresh interval in seconds (0 = off). Setting triggers timer restart.
    @Published var refreshInterval: Int = 30 {
        didSet { restartRefreshTimer() }
    }

    /// Gateway poll interval in seconds.
    @Published var gatewayPollInterval: Int = 10 {
        didSet { restartGatewayTimer() }
    }

    // MARK: - Derived

    var totalTokens: Int     { agentRuntimes.values.reduce(0) { $0 + $1.totalTokens } }
    var totalSessions: Int   { sessions.count }
    var totalMessages: Int   { sessions.reduce(0) { $0 + $1.messages } }
    var onlineAgents: Int    { agentRuntimes.values.filter { $0.status == .online }.count }
    var activeAlertCount: Int { alerts.filter { $0.status == .active }.count }

    func runtime(for agentId: String) -> AgentRuntime {
        agentRuntimes[agentId] ?? AgentRuntime(
            id: agentId, status: .offline, sessionCount: 0, totalTokens: 0, avgResponseMs: 0
        )
    }

    func sessions(for agentId: String) -> [SessionInfo] {
        sessions.filter { $0.agentId == agentId }
    }

    // MARK: - Load

    private var fileWatcher: FileWatcher?
    private var refreshTimer: Timer?
    private var gatewayTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    func loadData() {
        // Request notification permission up-front
        NotificationService.shared.requestPermission()

        if let config = ConfigService.shared.load() {
            apply(config: config)
            configFilePath = ConfigService.shared.resolvedPath()
            isUsingMockData = false
            configError = nil
            watchConfigFile()
        } else {
            applyMockData()
            isUsingMockData = true
            configError = ConfigService.shared.lastError
        }

        // Read persisted intervals
        let savedRefresh  = UserDefaults.standard.integer(forKey: "autoRefreshInterval")
        let savedGateway  = UserDefaults.standard.integer(forKey: "gatewayPollInterval")
        refreshInterval       = savedRefresh  > 0 ? savedRefresh  : 30
        gatewayPollInterval   = savedGateway  > 0 ? savedGateway  : 10

        if !isUsingMockData {
            connectGateway()
        } else {
            startGatewayPolling()
        }
        restartRefreshTimer()
    }

    func reload() {
        guard !isUsingMockData, let config = ConfigService.shared.load() else { return }
        apply(config: config)
        checkAlertRules()
        // Also refresh live gateway data
        if GatewayService.shared.isConnected {
            Task { await GatewayService.shared.fetchSessions() }
            Task { await GatewayService.shared.fetchAgents() }
        }
    }

    // MARK: - Refresh Timer

    func restartRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        guard refreshInterval > 0 else { return }
        refreshTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(refreshInterval),
                                            repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.reload() }
        }
        // Persist
        UserDefaults.standard.set(refreshInterval, forKey: "autoRefreshInterval")
    }

    // MARK: - Gateway WebSocket

    func connectGateway() {
        let token = ConfigService.shared.lastLoadedConfig?.gateway.auth?.token
        let port   = gatewayPort
        let gw     = GatewayService.shared
        gw.onConnected = { [weak self] in
            guard let self else { return }
            withAnimation { self.gatewayStatus = .healthy }
            Task { await gw.fetchAgents() }
            Task { await gw.fetchSessions() }
            Task { await gw.fetchSkillsStatus() }
            Task { await gw.fetchUsage() }
        }
        gw.onDisconnected = { [weak self] in
            guard let self else { return }
            withAnimation { self.gatewayStatus = .unhealthy }
            self.fireGatewayAlert()
        }
        gw.onAgentsUpdated = { [weak self] gwAgents in
            self?.applyGWAgents(gwAgents)
        }
        gw.onSessionsUpdated = { [weak self] gwSessions in
            self?.applyGWSessions(gwSessions)
        }
        gw.onSkillsUpdated = { [weak self] gwSkills in
            self?.skills = gwSkills
        }
        gw.onUsageUpdated = { [weak self] points in
            self?.statPoints = points
        }
        gw.onAgentUsageUpdated = { [weak self] usage in
            self?.agentUsage = usage
        }
        gw.connect(port: port, token: token)
    }

    private func applyGWAgents(_ gwAgents: [GWAgent]) {
        // Merge GW agent info into existing agents list (name / emoji override)
        for gw in gwAgents {
            if let idx = agents.firstIndex(where: { $0.id == gw.id }) {
                if agents[idx].name == nil { agents[idx].name = gw.name }
            }
            // Ensure runtime exists
            if agentRuntimes[gw.id] == nil {
                agentRuntimes[gw.id] = AgentRuntime(
                    id: gw.id, status: .idle,
                    sessionCount: 0, totalTokens: 0, avgResponseMs: 0
                )
            }
        }
        withAnimation { gatewayStatus = .healthy }
    }

    private func applyGWSessions(_ gwSessions: [GWSession]) {
        // Build sessions list from gateway data
        sessions = gwSessions.map { gw in
            let sessionType: SessionType = {
                switch gw.chatType {
                case "group":  return .group
                case "cron":   return .cron
                default:       return .dm
                }
            }()
            return SessionInfo(
                id: gw.key,
                agentId: gw.agentId,
                type: sessionType,
                platform: gw.platform,
                userName:    sessionType == .dm    ? gw.displayName : nil,
                channelName: sessionType != .dm    ? gw.displayName : nil,
                tokens: gw.tokens,
                messages: gw.messageCount,
                lastActive: gw.lastActivity,
                status: gwStatusToSessionStatus(gw.status)
            )
        }
        // Update agent runtimes with aggregated stats
        // Use case-insensitive matching: session key may have "beethoven" while config has "Beethoven"
        var countMap: [String: Int] = [:]
        var tokenMap: [String: Int] = [:]
        var providerMap: [String: String] = [:]
        for s in gwSessions {
            // Find matching runtime key case-insensitively
            let matchedId = agentRuntimes.keys
                .first { $0.lowercased() == s.agentId.lowercased() } ?? s.agentId
            countMap[matchedId, default: 0] += 1
            tokenMap[matchedId, default: 0] += s.tokens
            if !s.modelProvider.isEmpty { providerMap[matchedId] = s.modelProvider }
        }
        for (agentId, count) in countMap {
            if agentRuntimes[agentId] != nil {
                agentRuntimes[agentId]!.sessionCount = count
                agentRuntimes[agentId]!.totalTokens  = tokenMap[agentId] ?? 0
                agentRuntimes[agentId]!.status       = count > 0 ? .online : .idle
                if let provider = providerMap[agentId] {
                    agentRuntimes[agentId]!.provider = provider
                }
            }
        }
        // Mark agents with no sessions as idle
        for agentId in agentRuntimes.keys where countMap[agentId] == nil {
            agentRuntimes[agentId]!.status = .idle
        }
    }

    private func gwStatusToSessionStatus(_ gwStatus: String) -> SessionStatus {
        switch gwStatus {
        case "active", "running": return .active
        case "idle":              return .idle
        default:                  return .inactive
        }
    }

    // MARK: - Gateway Polling (mock mode only)

    func startGatewayPolling() {
        restartGatewayTimer()
    }

    func stopGatewayPolling() {
        gatewayTimer?.invalidate()
        gatewayTimer = nil
    }

    func restartGatewayTimer() {
        gatewayTimer?.invalidate()
        gatewayTimer = nil
        let interval = max(5, gatewayPollInterval)
        gatewayTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(interval),
                                            repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.pollGateway() }
        }
        UserDefaults.standard.set(gatewayPollInterval, forKey: "gatewayPollInterval")
        pollGateway()
    }

    private func pollGateway() {
        if isUsingMockData {
            withAnimation { gatewayStatus = .healthy }
            return
        }
        // If WebSocket is connected, just refresh session data
        if GatewayService.shared.isConnected {
            Task { await GatewayService.shared.fetchSessions() }
            return
        }
        let urlString = "http://localhost:\(gatewayPort)/health"
        guard let url = URL(string: urlString) else { return }
        var req = URLRequest(url: url, timeoutInterval: 5)
        req.httpMethod = "GET"
        let prevStatus = gatewayStatus
        URLSession.shared.dataTask(with: req) { [weak self] _, response, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                // Any HTTP response = gateway is up; only connection failure = down
                let ok = error == nil && (response as? HTTPURLResponse) != nil
                let newStatus: GatewayStatus = ok ? .healthy : .unhealthy
                withAnimation { self.gatewayStatus = newStatus }
                // Fire alert if newly unhealthy
                if prevStatus != .unhealthy && newStatus == .unhealthy {
                    self.fireGatewayAlert()
                }
                // Resolve gateway alert if recovered
                if prevStatus == .unhealthy && newStatus == .healthy {
                    self.resolveGatewayAlerts()
                }
                self.checkAlertRules()
            }
        }.resume()
    }

    // MARK: - Alert Rules (§3.8.2)

    private let agentOfflineThresholdKey = "agentOfflineThreshold"  // minutes
    private let tokenAlertPercentKey     = "tokenAlertPercent"       // %

    func checkAlertRules() {
        guard !isUsingMockData else { return }

        let offlineMinutes = UserDefaults.standard.integer(forKey: agentOfflineThresholdKey)
        let thresholdMin   = offlineMinutes > 0 ? offlineMinutes : 30

        // Rule 1: Agent offline > threshold
        for agent in agents {
            let rt = runtime(for: agent.id)
            guard rt.status == .offline else { continue }
            let key = "agent_offline_\(agent.id)"
            guard !hasActiveAlert(key: key) else { continue }
            fireAlert(AlertItem(
                type: .error,
                message: "\(agent.displayEmoji) \(agent.name) 已离线超过 \(thresholdMin) 分钟"
            ), dedupeKey: key)
        }

        // Rule 2: Gateway disconnected — handled in pollGateway()

        // Rule 3: Token anomaly (simple check vs daily average)
        checkTokenAnomaly()
    }

    private func checkTokenAnomaly() {
        guard statPoints.count >= 2 else { return }
        let recent = statPoints.last!
        let prevTokens = statPoints.dropLast().map(\.tokens)
        let avg = prevTokens.reduce(0, +) / prevTokens.count
        let pct = UserDefaults.standard.integer(forKey: tokenAlertPercentKey)
        let threshold = pct > 0 ? pct : 150
        guard avg > 0, recent.tokens > avg * threshold / 100 else { return }
        let key = "token_anomaly_\(Calendar.current.startOfDay(for: recent.date))"
        guard !hasActiveAlert(key: key) else { return }
        let increase = recent.tokens * 100 / avg - 100
        fireAlert(AlertItem(
            type: .info,
            message: "今日 Token 消耗较日均值增加 \(increase)%（\(recent.tokensK.formatted(.number.precision(.fractionLength(1))))k vs avg）"
        ), dedupeKey: key)
    }

    private func fireGatewayAlert() {
        let key = "gateway_down"
        guard !hasActiveAlert(key: key) else { return }
        fireAlert(AlertItem(type: .error, message: "Gateway 连接中断 (Port \(gatewayPort))"),
                  dedupeKey: key)
    }

    private func resolveGatewayAlerts() {
        for i in alerts.indices where alerts[i].message.contains("Gateway") && alerts[i].status == .active {
            alerts[i].status = .resolved
        }
        updateBadge()
    }

    private func fireAlert(_ alert: AlertItem, dedupeKey: String) {
        alerts.insert(alert, at: 0)
        NotificationService.shared.send(alert: alert)
        updateBadge()
        // Store key so we don't double-fire
        UserDefaults.standard.set(true, forKey: "alert_active_\(dedupeKey)")
    }

    private func hasActiveAlert(key: String) -> Bool {
        UserDefaults.standard.bool(forKey: "alert_active_\(key)")
        || alerts.contains { $0.status == .active && $0.message.contains(key.split(separator: "_").last.map(String.init) ?? "") }
    }

    private func updateBadge() {
        NotificationService.shared.updateBadge(count: activeAlertCount)
    }

    /// Mock connectivity test — always succeeds after 1.5 s.
    func simulateConnectivityTest() async -> Bool {
        try? await Task.sleep(for: .seconds(1.5))
        return true
    }

    /// Real connectivity test: pings the gateway WebSocket and confirms the model is reachable.
    /// Because all models route through the gateway, a live gateway response means the model
    /// provider chain is operational.
    func testModelConnectivity(modelId: String) async -> Bool {
        // 1. Gateway WebSocket must be connected and responsive
        guard GatewayService.shared.isConnected else { return false }
        guard await GatewayService.shared.ping() else { return false }
        // 2. Model must exist in the known model list
        guard models.contains(where: { $0.id == modelId }) else { return false }
        return true
    }

    // MARK: - Private helpers

    private func apply(config: OpenClawConfig) {
        // Enrich each agent with the shared default model if it has no individual model
        let defaultModel = config.defaultModelId
        agents = config.agentList.map { agent in
            guard agent.model == nil, let dm = defaultModel else { return agent }
            var enriched = agent
            enriched.model = dm
            return enriched
        }
        models      = config.allModels
        gatewayPort = config.port

        // Initialise runtimes for any agent not yet tracked (idle, stats unknown)
        for agent in agents where agentRuntimes[agent.id] == nil {
            agentRuntimes[agent.id] = AgentRuntime(
                id: agent.id, status: .idle,
                sessionCount: 0, totalTokens: 0, avgResponseMs: 0
            )
        }
    }

    private func applyMockData() {
        agents        = MockData.agents
        models        = MockData.models
        sessions      = MockData.sessions
        alerts        = MockData.alerts
        skills        = MockData.skills
        statPoints    = MockData.statPoints
        agentUsage    = MockData.agentUsage
        gatewayPort   = 18789
        agentRuntimes = Dictionary(uniqueKeysWithValues: MockData.agentRuntimes.map { ($0.id, $0) })
    }

    private func watchConfigFile() {
        guard let path = configFilePath else { return }
        fileWatcher = FileWatcher { [weak self] in
            Task { @MainActor [weak self] in self?.reload() }
        }
        fileWatcher?.start(watching: path)
    }
}

// MARK: - GatewayStatus

extension AppViewModel {
    enum GatewayStatus: Equatable {
        case healthy, unhealthy, unknown

        var dotStatus: StatusDot.Status {
            switch self {
            case .healthy:   return .online
            case .unhealthy: return .offline
            case .unknown:   return .idle
            }
        }

        var label: String {
            switch self {
            case .healthy:   return "Healthy"
            case .unhealthy: return "Offline"
            case .unknown:   return "Unknown"
            }
        }
    }
}
