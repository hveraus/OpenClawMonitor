import SwiftUI

struct ModelsView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var sortOrder = [KeyPathComparator(\ModelInfo.name)]
    @State private var testStates: [String: TestState] = [:]

    var body: some View {
        Table(viewModel.models, sortOrder: $sortOrder) {
            TableColumn("模型名称", value: \.name) { m in
                Text(m.name)
                    .font(.subheadline).fontWeight(.medium)
            }
            TableColumn("Provider", value: \.provider) { m in
                PlatformBadge(platform: m.provider)
            }
            TableColumn("上下文", value: \.contextWindowFormatted) { m in
                Text(m.contextWindowFormatted)
                    .font(.system(.caption, design: .monospaced))
            }
            TableColumn("最大输出", value: \.maxTokensFormatted) { m in
                Text(m.maxTokensFormatted)
                    .font(.system(.caption, design: .monospaced))
            }
            TableColumn("推理") { m in
                Image(systemName: m.reasoning ? "checkmark.circle.fill" : "xmark.circle")
                    .foregroundStyle(m.reasoning ? .green : .secondary)
                    .symbolRenderingMode(.hierarchical)
            }
            .width(44)
            TableColumn("视觉") { m in
                Image(systemName: m.vision ? "checkmark.circle.fill" : "xmark.circle")
                    .foregroundStyle(m.vision ? .green : .secondary)
                    .symbolRenderingMode(.hierarchical)
            }
            .width(44)
            TableColumn("成本 (输入/输出 / 1M)", value: \.costFormatted) { m in
                VStack(alignment: .leading, spacing: 1) {
                    Text(m.costFormatted)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(m.hasZeroCost ? .secondary : .primary)
                    if !m.costSource.isEmpty && m.hasZeroCost {
                        Text(m.costSource)
                            .font(.system(size: 9))
                            .foregroundStyle(.orange.opacity(0.8))
                    }
                }
            }
            TableColumn("测试") { m in
                ConnectivityTestButton(
                    state: .init(
                        get: { testStates[m.id, default: .idle] },
                        set: { testStates[m.id] = $0 }
                    )
                ) {
                    await runTest(for: m.id)
                }
            }
            .width(110)
        }
        .onChange(of: sortOrder) { _, newOrder in
            viewModel.models.sort(using: newOrder)
        }
        .background(Color(.windowBackgroundColor))
    }

    private func runTest(for modelId: String) async {
        testStates[modelId] = .testing
        let ok = viewModel.isUsingMockData
            ? await viewModel.simulateConnectivityTest()
            : await viewModel.testModelConnectivity(modelId: modelId)
        withAnimation { testStates[modelId] = ok ? .success : .failure }
        try? await Task.sleep(for: .seconds(3))
        withAnimation { testStates[modelId] = .idle }
    }
}
