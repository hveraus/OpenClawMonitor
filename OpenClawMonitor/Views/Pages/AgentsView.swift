import SwiftUI

struct AgentsView: View {
    @EnvironmentObject var viewModel: AppViewModel

    @State private var tokenPeriod: TokenPeriod = .all
    @State private var customStart: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var customEnd:   Date = Date()

    private let columns = [GridItem(.adaptive(minimum: 300, maximum: 420), spacing: 16)]

    // Computed once per render pass; avoids calling agentTokens 2× per agent.
    private var tokenCounts: [String: Int] {
        Dictionary(uniqueKeysWithValues: viewModel.agents.map { agent in
            (agent.id, viewModel.agentTokens(
                for: agent.id,
                period: tokenPeriod,
                customStart: customStart,
                customEnd: customEnd
            ))
        })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // ── Period selector ────────────────────────────────────────
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text("时间段:")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Picker("时间段", selection: $tokenPeriod) {
                            ForEach(TokenPeriod.allCases, id: \.self) { p in
                                Text(p.rawValue).tag(p)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 380)
                    }

                    if tokenPeriod == .custom {
                        HStack(spacing: 12) {
                            DatePicker("开始", selection: $customStart,
                                       in: ...customEnd, displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                            Text("—").foregroundStyle(.secondary)
                            DatePicker("结束", selection: $customEnd,
                                       in: customStart..., displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(.horizontal, 20)
                .animation(.easeInOut(duration: 0.2), value: tokenPeriod)

                // ── Top stats strip ────────────────────────────────────────
                let counts = tokenCounts
                HStack(spacing: 12) {
                    StatCard(icon: "circle.hexagongrid.fill",
                             value: formatTokens(counts.values.reduce(0, +)),
                             label: "总 Token 用量")
                    StatCard(icon: "bubble.left.and.text.bubble.right",
                             value: "\(viewModel.totalSessions)",
                             label: "总会话数")
                    StatCard(icon: "person.fill.checkmark",
                             value: "\(viewModel.onlineAgents)",
                             label: "在线 Agent")
                }
                .padding(.horizontal, 20)

                // ── Agent cards ────────────────────────────────────────────
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(viewModel.agents) { agent in
                        AgentCard(
                            agent: agent,
                            runtime: viewModel.runtime(for: agent.id),
                            tokenCount: counts[agent.id] ?? 0,
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
