import SwiftUI

struct MainWindow: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var sidebarSelection: SidebarItem? = .agents
    @State private var refreshRotation: Double = 0
    @State private var isRefreshing = false

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $sidebarSelection)
        } detail: {
            ZStack(alignment: .bottom) {
                contentView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if viewModel.isUsingMockData {
                    MockDataBanner(error: viewModel.configError)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: viewModel.isUsingMockData)
        }
        .animation(.easeInOut(duration: 0.2), value: sidebarSelection)
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                // Gateway status indicator
                HStack(spacing: 6) {
                    StatusDot(status: viewModel.gatewayStatus.dotStatus, size: 7)
                    Text("Port \(viewModel.gatewayPort)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Refresh button with rotation animation
                Button {
                    triggerRefresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.body)
                        .rotationEffect(.degrees(refreshRotation))
                }
                .help("刷新数据")
                .disabled(isRefreshing)
            }
        }
        .toolbarBackground(.visible, for: .windowToolbar)
    }

    @ViewBuilder
    private var contentView: some View {
        switch sidebarSelection {
        case .agents:      AgentsView()
        case .models:      ModelsView()
        case .sessions:    SessionsView()
        case .statistics:  StatisticsView()
        case .skills:      SkillsView()
        case .alerts:      AlertsView()
        case .pixelOffice: PixelOfficeView()
        case nil:          AgentsView()
        }
    }

    private func triggerRefresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        withAnimation(.linear(duration: 0.6)) {
            refreshRotation += 360
        }
        viewModel.reload()
        Task {
            try? await Task.sleep(for: .seconds(0.7))
            isRefreshing = false
        }
    }
}

// MARK: - Demo Mode Banner

private struct MockDataBanner: View {
    let error: String?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: error != nil ? "exclamationmark.triangle.fill" : "flask.fill")
                .font(.callout)
                .foregroundStyle(.yellow)
                .symbolRenderingMode(.hierarchical)
            VStack(alignment: .leading, spacing: 1) {
                Text("Demo Mode")
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(.yellow)
                if let error {
                    Text("解析失败：\(error)")
                        .font(.caption2)
                        .foregroundStyle(.primary.opacity(0.7))
                } else {
                    Text("未检测到 OpenClaw 配置 — 当前显示内置示例数据")
                        .font(.caption2)
                        .foregroundStyle(.primary.opacity(0.7))
                }
            }
            Spacer()
            Text("~/.openclaw/openclaw.json")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .fontDesign(.monospaced)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(.yellow.opacity(0.10))
        .overlay(alignment: .top) { Divider().opacity(0.4) }
    }
}
