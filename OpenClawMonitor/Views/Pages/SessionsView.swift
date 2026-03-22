import SwiftUI

struct SessionsView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var filterAgentId: String = "all"
    @State private var testStates: [String: TestState] = [:]

    private var filteredSessions: [SessionInfo] {
        filterAgentId == "all"
            ? viewModel.sessions
            : viewModel.sessions.filter { $0.agentId == filterAgentId }
    }

    // Group sessions by agent
    private var grouped: [(agent: AgentConfig?, sessions: [SessionInfo])] {
        let agentMap = Dictionary(uniqueKeysWithValues: viewModel.agents.map { ($0.id, $0) })
        let byAgent = Dictionary(grouping: filteredSessions, by: \.agentId)
        return byAgent.map { (agentId, sessions) in
            (agent: agentMap[agentId], sessions: sessions.sorted { $0.lastActive > $1.lastActive })
        }.sorted { ($0.agent?.name ?? "") < ($1.agent?.name ?? "") }
    }

    var body: some View {
        VStack(spacing: 0) {

            // ── Filter picker ──────────────────────────────────────────────
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(label: "全部", isSelected: filterAgentId == "all") {
                        filterAgentId = "all"
                    }
                    ForEach(viewModel.agents) { agent in
                        FilterChip(
                            label: "\(agent.displayEmoji) \(agent.name)",
                            isSelected: filterAgentId == agent.id
                        ) {
                            filterAgentId = agent.id
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            Divider()

            // ── Session list ───────────────────────────────────────────────
            List {
                ForEach(grouped, id: \.agent?.id) { group in
                    Section {
                        ForEach(group.sessions) { session in
                            SessionRow(
                                session: session,
                                agent: group.agent,
                                testState: .init(
                                    get: { testStates[session.id, default: .idle] },
                                    set: { testStates[session.id] = $0 }
                                ),
                                isMockMode: viewModel.isUsingMockData
                            ) {
                                await runTest(for: session.id)
                            }
                        }
                    } header: {
                        if let agent = group.agent {
                            Text("\(agent.displayEmoji) \(agent.name)")
                                .font(.subheadline).fontWeight(.semibold)
                        }
                    }
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
        }
        .background(Color(.windowBackgroundColor))
        .animation(.easeInOut(duration: 0.2), value: filterAgentId)
    }

    private func runTest(for sessionId: String) async {
        testStates[sessionId] = .testing
        let ok = viewModel.isUsingMockData
            ? await viewModel.simulateConnectivityTest()
            : false
        withAnimation { testStates[sessionId] = ok ? .success : .failure }
        try? await Task.sleep(for: .seconds(3))
        withAnimation { testStates[sessionId] = .idle }
    }
}

// MARK: - Session row

private struct SessionRow: View {
    let session: SessionInfo
    let agent: AgentConfig?
    @Binding var testState: TestState
    let isMockMode: Bool
    let onTest: () async -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Type icon
            Image(systemName: session.typeIcon)
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(width: 20)

            // Target
            VStack(alignment: .leading, spacing: 2) {
                Text(session.displayTarget)
                    .font(.subheadline).fontWeight(.medium)
                Text(session.typeLabel)
                    .font(.caption).foregroundStyle(.secondary)
            }
            .frame(minWidth: 120, alignment: .leading)

            PlatformBadge(platform: session.platform)

            Spacer()

            // Stats
            HStack(spacing: 16) {
                LabeledValue(label: "Token", value: session.tokensFormatted)
                LabeledValue(label: "消息",  value: "\(session.messages)")
            }

            // Status dot
            HStack(spacing: 4) {
                StatusDot(status: session.status.dotStatus)
                Text(session.status.label)
                    .font(.caption).foregroundStyle(.secondary)
            }

            // Last active
            Text(session.lastActive, style: .relative)
                .font(.caption).foregroundStyle(.secondary)
                .frame(width: 70, alignment: .trailing)

            // Test button
            ConnectivityTestButton(state: $testState, action: onTest)
                .frame(width: 100)
        }
        .padding(.vertical, 4)
    }
}

extension SessionStatus {
    var dotStatus: StatusDot.Status {
        switch self {
        case .active:   return .online
        case .idle:     return .idle
        case .inactive: return .offline
        }
    }
}

// MARK: - Helpers

private struct LabeledValue: View {
    let label: String
    let value: String
    var body: some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(value).font(.caption).fontWeight(.semibold)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }
}

private struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption).fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12).padding(.vertical, 5)
                .background(
                    isSelected ? Color.indigo.opacity(0.25) : Color.primary.opacity(isHovered ? 0.08 : 0.05),
                    in: Capsule()
                )
                .foregroundStyle(isSelected ? .indigo : .primary)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
