import SwiftUI

struct AgentsView: View {
    @EnvironmentObject var viewModel: AppViewModel

    private let columns = [GridItem(.adaptive(minimum: 300, maximum: 420), spacing: 16)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // ── Top stats strip (§3.3.1) ───────────────────────────────
                HStack(spacing: 12) {
                    StatCard(icon: "circle.hexagongrid.fill",
                             value: formatTokens(viewModel.totalTokens),
                             label: "总 Token 用量")
                    StatCard(icon: "bubble.left.and.text.bubble.right",
                             value: "\(viewModel.totalSessions)",
                             label: "总会话数")
                    StatCard(icon: "person.fill.checkmark",
                             value: "\(viewModel.onlineAgents)",
                             label: "在线 Agent")
                }
                .padding(.horizontal, 20)

                // ── Agent cards (§3.3.2) ───────────────────────────────────
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(viewModel.agents) { agent in
                        AgentCard(
                            agent: agent,
                            runtime: viewModel.runtime(for: agent.id),
                            isMockMode: viewModel.isUsingMockData
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }
                }
                .padding(.horizontal, 20)
                .animation(.spring(response: 0.4), value: viewModel.agents.count)
            }
            .padding(.vertical, 20)
        }
        .background(Color(.windowBackgroundColor))
    }

    private func formatTokens(_ n: Int) -> String {
        n >= 1_000_000
            ? String(format: "%.2fM", Double(n) / 1_000_000)
            : String(format: "%.1fk", Double(n) / 1_000)
    }
}
