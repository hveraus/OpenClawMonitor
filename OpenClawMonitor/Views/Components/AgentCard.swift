import SwiftUI

struct AgentCard: View {
    let agent: AgentConfig
    let runtime: AgentRuntime
    let isMockMode: Bool

    @State private var isHovered  = false
    @State private var testState: TestState = .idle

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // ── Header ─────────────────────────────────────────────────────
            HStack(spacing: 10) {
                Text(agent.displayEmoji)
                    .font(.title)
                VStack(alignment: .leading, spacing: 2) {
                    Text(agent.name)
                        .font(.headline).fontWeight(.semibold)
                    Text(agent.model ?? "未配置模型")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    StatusDot(status: runtime.status.dotStatus, size: 9)
                    Text(runtime.status.label)
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }

            // ── Platform badges ─────────────────────────────────────────────
            if let platforms = agent.platforms, !platforms.isEmpty {
                HStack(spacing: 4) {
                    ForEach(platforms, id: \.self) { PlatformBadge(platform: $0) }
                }
            }

            Divider()

            // ── Stats grid ──────────────────────────────────────────────────
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                AgentStat(label: "会话数",   value: "\(runtime.sessionCount)")
                AgentStat(label: "Token",   value: tokenLabel(runtime.totalTokens))
                AgentStat(label: "平均响应", value: "\(runtime.avgResponseMs) ms")
                AgentStat(label: "Provider", value: providerName(agent.model))
            }

            // ── Connectivity test ───────────────────────────────────────────
            ConnectivityTestButton(state: $testState) {
                await runTest()
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(isHovered ? 0.18 : 0.06),
                radius: isHovered ? 14 : 5)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .onHover { isHovered = $0 }
    }

    // MARK: - Private

    private func runTest() async {
        testState = .testing
        let ok: Bool
        if isMockMode {
            ok = await fakeTest()
        } else {
            ok = await realTest()
        }
        withAnimation { testState = ok ? .success : .failure }
        try? await Task.sleep(for: .seconds(3))
        withAnimation { testState = .idle }
    }

    private func fakeTest() async -> Bool {
        try? await Task.sleep(for: .seconds(1.5))
        return true
    }

    private func realTest() async -> Bool {
        guard let url = URL(string: "http://localhost:18789/api/health") else { return false }
        var req = URLRequest(url: url, timeoutInterval: 5)
        req.httpMethod = "GET"
        return (try? await URLSession.shared.data(for: req))
            .flatMap { _, res in (res as? HTTPURLResponse)?.statusCode == 200 } ?? false
    }

    private func tokenLabel(_ n: Int) -> String {
        n >= 1_000_000 ? String(format: "%.1fM", Double(n)/1_000_000)
                       : String(format: "%.1fk", Double(n)/1_000)
    }

    private func providerName(_ model: String?) -> String {
        guard let m = model?.lowercased() else { return "—" }
        if m.contains("claude")    { return "Anthropic" }
        if m.contains("gpt")       { return "OpenAI" }
        if m.contains("deepseek")  { return "DeepSeek" }
        if m.contains("gemini")    { return "Google" }
        return "Unknown"
    }
}

// MARK: - Tiny stat item

private struct AgentStat: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption2).foregroundStyle(.secondary)
            Text(value)
                .font(.title3).fontWeight(.semibold)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - AgentRuntime convenience

extension AgentRuntime.AgentStatus {
    var dotStatus: StatusDot.Status {
        switch self {
        case .online:  return .online
        case .idle:    return .idle
        case .offline: return .offline
        }
    }
}
