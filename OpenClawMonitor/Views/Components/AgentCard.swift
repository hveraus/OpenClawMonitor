import SwiftUI

struct AgentCard: View {
    let agent: AgentConfig
    let runtime: AgentRuntime
    let tokenCount: Int
    let isMockMode: Bool

    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // ── Header ─────────────────────────────────────────────────────
            HStack(spacing: 10) {
                Text(agent.displayEmoji)
                    .font(.largeTitle)
                VStack(alignment: .leading, spacing: 2) {
                    Text(agent.displayName)
                        .font(.title3).fontWeight(.semibold)
                    Text(displayModel)
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    StatusDot(status: runtime.status.dotStatus, size: 9)
                    Text(runtime.status.label)
                        .font(.caption).foregroundStyle(.secondary)
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
                AgentStat(label: "Token",   value: tokenLabel(tokenCount))
                AgentStat(label: "平均响应", value: avgResponseLabel)
                AgentStat(label: "Provider", value: providerName(displayModel, hint: runtime.provider))
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

    /// Shows last-used model from live sessions; falls back to configured default.
    private var displayModel: String {
        runtime.lastModel ?? agent.model ?? "未配置模型"
    }

    private var avgResponseLabel: String {
        runtime.avgResponseMs > 0 ? "\(runtime.avgResponseMs) ms" : "—"
    }

    private func tokenLabel(_ n: Int) -> String {
        n >= 1_000_000 ? String(format: "%.1fM", Double(n)/1_000_000)
                       : String(format: "%.1fk", Double(n)/1_000)
    }

    /// Derive a human-readable provider name from the model ID.
    /// `hint` is the raw provider string from the session's model-snapshot
    /// (e.g. "kimi", "yunwu-claude") used as fallback when the model name
    /// alone is not enough to identify the vendor.
    private func providerName(_ model: String, hint: String = "") -> String {
        let m = model.lowercased()
        if m.contains("claude")           { return "Anthropic" }
        if m.contains("gpt") || m.hasPrefix("o1") || m.hasPrefix("o3") { return "OpenAI" }
        if m.contains("gemini") || m.contains("vertex") { return "Google" }
        if m.contains("deepseek")         { return "DeepSeek" }
        if m.contains("kimi") || m.contains("moonshot") { return "Moonshot" }
        if m.contains("qwen") || m.contains("dashscope") { return "Alibaba" }
        if m.contains("glm") || m.contains("zhipu")     { return "Zhipu" }
        if m.contains("mistral")          { return "Mistral" }
        if m.contains("grok") || m.contains("xai")      { return "xAI" }
        if m.contains("llama") || m.contains("meta")    { return "Meta" }

        // Fall back to the session-level provider hint
        let h = hint.lowercased()
        if h.contains("kimi")       { return "Moonshot" }
        if h.contains("moonshot")   { return "Moonshot" }
        if h.contains("claude")     { return "Anthropic" }
        if h.contains("openai")     { return "OpenAI" }
        if h.contains("deepseek")   { return "DeepSeek" }
        if h.contains("gemini") || h.contains("google") { return "Google" }
        if h.contains("qwen") || h.contains("dashscope") { return "Alibaba" }
        if h.contains("mistral")    { return "Mistral" }
        if h.contains("grok")       { return "xAI" }
        if !hint.isEmpty            { return hint }   // show raw if unknown
        return "—"
    }
}

// MARK: - Tiny stat item

private struct AgentStat: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption).foregroundStyle(.secondary)
            Text(value)
                .font(.title2).fontWeight(.semibold)
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
