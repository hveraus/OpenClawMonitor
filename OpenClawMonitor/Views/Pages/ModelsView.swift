import SwiftUI

// MARK: - ModelsView (tab container)

struct ModelsView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var tab: ModelsTab = .configured

    enum ModelsTab { case configured, yunwu, litellm }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Picker("", selection: $tab) {
                    Text("已配置模型").tag(ModelsTab.configured)
                    Text("Yunwu").tag(ModelsTab.yunwu)
                    Text("LiteLLM").tag(ModelsTab.litellm)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 300)

                Spacer()

                switch tab {
                case .configured: Text("\(viewModel.models.count) 个模型").font(.caption).foregroundStyle(.secondary)
                case .yunwu:      YunwuCounter()
                case .litellm:    LiteLLMCounter()
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            Divider()

            switch tab {
            case .configured: ConfiguredModelsTable()
            case .yunwu:      YunwuModelsView(configuredIds: Set(viewModel.models.map(\.id)))
            case .litellm:    LiteLLMModelsView(configuredIds: Set(viewModel.models.map(\.id)))
            }
        }
        .background(Color(.windowBackgroundColor))
        .task {
            PriceRefreshService.shared.loadCacheAndRefresh()
            LiteLLMService.shared.loadCacheAndRefresh()
        }
    }
}

// MARK: - Counters

private struct YunwuCounter: View {
    @StateObject private var svc = PriceRefreshService.shared
    var body: some View {
        HStack(spacing: 6) {
            if svc.isRefreshing {
                ProgressView().controlSize(.mini)
                Text("更新中…").font(.caption).foregroundStyle(.secondary)
            } else {
                let total = svc.byVendor.reduce(0) { $0 + $1.models.count }
                Text(total > 0 ? "\(total) 个模型" : "离线缓存").font(.caption).foregroundStyle(.secondary)
                if let d = svc.lastUpdated {
                    Text("· \(d, style: .relative)前").font(.caption).foregroundStyle(.tertiary)
                }
            }
        }
    }
}

private struct LiteLLMCounter: View {
    @StateObject private var svc = LiteLLMService.shared
    var body: some View {
        HStack(spacing: 6) {
            if svc.isRefreshing {
                ProgressView().controlSize(.mini)
                Text("更新中…").font(.caption).foregroundStyle(.secondary)
            } else {
                let total = svc.byProvider.reduce(0) { $0 + $1.entries.count }
                Text(total > 0 ? "\(total) 个模型" : "未加载").font(.caption).foregroundStyle(.secondary)
                if let d = svc.lastUpdated {
                    Text("· \(d, style: .relative)前").font(.caption).foregroundStyle(.tertiary)
                }
            }
        }
    }
}

// MARK: - Configured models (Table)

private struct ConfiguredModelsTable: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var sortOrder = [KeyPathComparator(\ModelInfo.name)]
    @State private var testStates: [String: TestState] = [:]

    var body: some View {
        Table(viewModel.models, sortOrder: $sortOrder) {
            TableColumn("模型名称", value: \.name) { m in
                Text(m.name).font(.subheadline).fontWeight(.medium)
            }
            TableColumn("Provider", value: \.provider) { m in
                PlatformBadge(platform: m.provider)
            }
            TableColumn("上下文", value: \.contextWindowFormatted) { m in
                Text(m.contextWindowFormatted).font(.system(.caption, design: .monospaced))
            }
            TableColumn("最大输出", value: \.maxTokensFormatted) { m in
                Text(m.maxTokensFormatted).font(.system(.caption, design: .monospaced))
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
                        Text(m.costSource).font(.system(size: 9)).foregroundStyle(.orange.opacity(0.8))
                    }
                }
            }
            TableColumn("测试") { m in
                ConnectivityTestButton(
                    state: .init(get: { testStates[m.id, default: .idle] },
                                 set: { testStates[m.id] = $0 })
                ) { await runTest(for: m.id) }
            }
            .width(110)
        }
        .onChange(of: sortOrder) { _, newOrder in viewModel.models.sort(using: newOrder) }
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

// MARK: - Yunwu models

private struct YunwuModelsView: View {
    let configuredIds: Set<String>
    @StateObject private var svc = PriceRefreshService.shared
    @State private var searchText = ""

    private var sections: [(vendor: String, models: [LiveModelPrice])] {
        let base = svc.byVendor.isEmpty
            ? []                // no static fallback for yunwu
            : svc.byVendor
        guard !searchText.isEmpty else { return base }
        return base.compactMap { s in
            let f = s.models.filter {
                $0.modelName.localizedCaseInsensitiveContains(searchText)
                || s.vendor.localizedCaseInsensitiveContains(searchText)
                || $0.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
            return f.isEmpty ? nil : (vendor: s.vendor, models: f)
        }
    }

    var body: some View {
        Group {
            if svc.byVendor.isEmpty && !svc.isRefreshing {
                emptyState(icon: "arrow.down.circle", msg: "价格数据加载中…",
                           sub: "首次启动需要从 yunwu.ai 拉取数据")
            } else {
                List {
                    errorBanner(svc.lastError)
                    ForEach(sections, id: \.vendor) { section in
                        Section {
                            ForEach(section.models) { m in
                                YunwuModelRow(model: m,
                                              isConfigured: configuredIds.contains(m.modelName))
                            }
                        } header: {
                            ProviderSectionHeader(name: section.vendor, count: section.models.count)
                        }
                    }
                }
                .listStyle(.inset)
                .searchable(text: $searchText, prompt: "搜索模型名称、厂商或标签")
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button { svc.forceRefresh() } label: {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
                .disabled(svc.isRefreshing)
                .help("立即从 yunwu.ai 刷新最新价格")
            }
        }
    }
}

private struct YunwuModelRow: View {
    let model: LiveModelPrice
    let isConfigured: Bool
    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.modelName).font(.system(.body, design: .monospaced))
                if !model.tags.isEmpty {
                    Text(model.tags.joined(separator: " · "))
                        .font(.caption2).foregroundStyle(.tertiary)
                }
            }
            Spacer()
            if isConfigured { ConfiguredBadge() }
            if model.perRequest {
                TagBadge("按次计费", color: .purple)
            } else {
                Text("⚡\(fmt(model.inputPer1M)) / ⚡\(fmt(model.outputPer1M))")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 115, alignment: .trailing)
            }
        }
        .padding(.vertical, 2)
    }
    private func fmt(_ v: Double) -> String {
        v < 0.01 ? String(format: "%.4f", v)
        : v < 1   ? String(format: "%.3f", v)
        : String(format: "%.2f", v)
    }
}

// MARK: - LiteLLM models

private struct LiteLLMModelsView: View {
    let configuredIds: Set<String>
    @StateObject private var svc = LiteLLMService.shared
    @State private var searchText = ""

    private var sections: [(provider: String, entries: [LiteLLMEntry])] {
        guard !searchText.isEmpty else { return svc.byProvider }
        return svc.byProvider.compactMap { s in
            let f = s.entries.filter {
                $0.modelName.localizedCaseInsensitiveContains(searchText)
                || s.provider.localizedCaseInsensitiveContains(searchText)
            }
            return f.isEmpty ? nil : (provider: s.provider, entries: f)
        }
    }

    var body: some View {
        Group {
            if svc.byProvider.isEmpty && !svc.isRefreshing {
                emptyState(icon: "arrow.down.circle", msg: "价格数据加载中…",
                           sub: "首次启动需要从 GitHub 拉取 LiteLLM 数据")
            } else {
                List {
                    errorBanner(svc.lastError)
                    ForEach(sections, id: \.provider) { section in
                        Section {
                            ForEach(section.entries) { entry in
                                LiteLLMModelRow(entry: entry,
                                                isConfigured: configuredIds.contains(entry.modelName))
                            }
                        } header: {
                            ProviderSectionHeader(name: section.provider, count: section.entries.count)
                        }
                    }
                }
                .listStyle(.inset)
                .searchable(text: $searchText, prompt: "搜索模型名称或 provider")
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button { svc.forceRefresh() } label: {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
                .disabled(svc.isRefreshing)
                .help("立即从 GitHub 刷新 LiteLLM 价格数据")
            }
        }
    }
}

private struct LiteLLMModelRow: View {
    let entry: LiteLLMEntry
    let isConfigured: Bool
    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.modelName).font(.system(.body, design: .monospaced))
                // Capability icons
                HStack(spacing: 6) {
                    if let ctx = entry.maxInputTokens {
                        Text(formatTokens(ctx)).font(.caption2).foregroundStyle(.tertiary)
                    }
                    capIcon("eye", active: entry.supportsVision, label: "视觉")
                    capIcon("brain", active: entry.supportsReasoning, label: "推理")
                    capIcon("wrench.and.screwdriver", active: entry.supportsFunctions, label: "工具")
                }
            }
            Spacer()
            if isConfigured { ConfiguredBadge() }
            // Price
            VStack(alignment: .trailing, spacing: 1) {
                Text("$\(fmt(entry.inputPerMillion)) in")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                Text("$\(fmt(entry.outputPerMillion)) out")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .frame(minWidth: 100, alignment: .trailing)
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func capIcon(_ icon: String, active: Bool, label: String) -> some View {
        if active {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .help(label)
        }
    }

    private func fmt(_ v: Double) -> String {
        v == 0    ? "0"
        : v < 0.01 ? String(format: "%.4f", v)
        : v < 1    ? String(format: "%.3f", v)
        : String(format: "%.2f", v)
    }

    private func formatTokens(_ n: Int) -> String {
        n >= 1_000_000 ? "\(n / 1_000_000)M ctx"
        : n >= 1_000   ? "\(n / 1_000)K ctx"
        : "\(n) ctx"
    }
}

// MARK: - Shared helpers

private struct ProviderSectionHeader: View {
    let name: String
    let count: Int
    var body: some View {
        HStack(spacing: 8) {
            PlatformBadge(platform: slug(name))
            Text(name).font(.subheadline).fontWeight(.semibold)
            Spacer()
            Text("\(count) 个").font(.caption2).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
    private func slug(_ n: String) -> String {
        let map: [String: String] = [
            "Anthropic": "anthropic", "OpenAI": "openai", "Google": "google",
            "DeepSeek": "deepseek", "Moonshot": "moonshot", "Moonshot / Kimi": "moonshot",
            "Alibaba Cloud": "qwen", "Alibaba Qwen": "qwen",
            "Zhipu": "zhipu", "MiniMax": "minimax",
            "ByteDance": "bytedance", "xAI": "xai", "Mistral": "mistral",
            "Xiaomi": "xiaomi", "Xiaomi MiMo": "xiaomi",
            "gemini": "google", "vertex_ai": "google", "vertex_ai-language-models": "google",
            "openai": "openai", "azure": "azure", "azure_ai": "azure",
            "anthropic": "anthropic", "deepseek": "deepseek", "xai": "xai",
            "mistral": "mistral", "dashscope": "qwen", "bedrock": "aws",
            "bedrock_converse": "aws",
        ]
        return map[n] ?? n.components(separatedBy: ["_", "-", " "]).first?.lowercased() ?? n.lowercased()
    }
}

private struct ConfiguredBadge: View {
    var body: some View {
        Text("已配置")
            .font(.caption2).fontWeight(.semibold)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(.green.opacity(0.15), in: Capsule())
            .foregroundStyle(.green)
    }
}

private struct TagBadge: View {
    let text: String
    let color: Color
    init(_ text: String, color: Color) { self.text = text; self.color = color }
    var body: some View {
        Text(text)
            .font(.caption2).fontWeight(.medium)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(color.opacity(0.12), in: Capsule())
            .foregroundStyle(color)
    }
}

@ViewBuilder
private func errorBanner(_ error: String?) -> some View {
    if let err = error {
        Label("加载失败：\(err)", systemImage: "exclamationmark.triangle")
            .font(.caption).foregroundStyle(.orange)
            .listRowBackground(Color.orange.opacity(0.08))
    }
}

@ViewBuilder
private func emptyState(icon: String, msg: String, sub: String) -> some View {
    VStack(spacing: 14) {
        Image(systemName: icon)
            .font(.system(size: 44))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(.secondary)
        Text(msg).font(.title3).fontWeight(.medium).foregroundStyle(.secondary)
        Text(sub).font(.caption).foregroundStyle(.tertiary).multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
}
