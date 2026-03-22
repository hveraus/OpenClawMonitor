import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @EnvironmentObject var viewModel: AppViewModel

    var body: some View {
        TabView {
            GeneralSettingsPane()
                .environmentObject(viewModel)
                .tabItem { Label("通用", systemImage: "gear") }
            AlertSettingsPane()
                .tabItem { Label("告警", systemImage: "bell.badge") }
            AboutPane()
                .environmentObject(viewModel)
                .tabItem { Label("关于", systemImage: "info.circle") }
        }
        .frame(width: 480, height: 360)
    }
}

// MARK: - General

private struct GeneralSettingsPane: View {
    @EnvironmentObject var viewModel: AppViewModel
    @AppStorage("colorSchemePreference") private var colorScheme = "dark"
    @State private var loginItemEnabled = false

    var body: some View {
        Form {
            Section("刷新") {
                // Bound directly to AppViewModel so timer restarts immediately
                Picker("自动刷新间隔", selection: $viewModel.refreshInterval) {
                    Text("关闭").tag(0)
                    Text("10 秒").tag(10)
                    Text("30 秒").tag(30)
                    Text("1 分钟").tag(60)
                    Text("5 分钟").tag(300)
                }
                Picker("Gateway 轮询间隔", selection: $viewModel.gatewayPollInterval) {
                    Text("5 秒").tag(5)
                    Text("10 秒").tag(10)
                    Text("30 秒").tag(30)
                }
            }

            Section("外观") {
                Picker("主题", selection: $colorScheme) {
                    Text("Dark").tag("dark")
                    Text("Light").tag("light")
                    Text("跟随系统").tag("system")
                }
            }

            Section("启动") {
                Toggle("开机自动启动", isOn: $loginItemEnabled)
                    .onChange(of: loginItemEnabled) { _, enabled in
                        setLoginItem(enabled: enabled)
                    }
                    .onAppear { loginItemEnabled = loginItemStatus() }
            }
        }
        .formStyle(.grouped)
        .padding(.vertical, 8)
    }

    private func loginItemStatus() -> Bool {
        SMAppService.mainApp.status == .enabled
    }

    private func setLoginItem(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("[Settings] Login item error: \(error)")
            loginItemEnabled = loginItemStatus()
        }
    }
}

// MARK: - Alerts

private struct AlertSettingsPane: View {
    @AppStorage("notificationsEnabled")  private var notificationsEnabled = true
    @AppStorage("agentOfflineThreshold") private var agentOfflineMin      = 30
    @AppStorage("responseTimeoutSec")    private var responseTimeoutSec   = 5
    @AppStorage("tokenAlertPercent")     private var tokenAlertPct        = 150
    @AppStorage("menuBarBadgeEnabled")   private var badgeEnabled         = true

    var body: some View {
        Form {
            Section("通知") {
                Toggle("启用 macOS 系统通知", isOn: $notificationsEnabled)
                    .onChange(of: notificationsEnabled) { _, enabled in
                        if enabled { NotificationService.shared.requestPermission() }
                    }
                Toggle("菜单栏角标显示", isOn: $badgeEnabled)
            }
            Section("告警阈值") {
                Stepper("Agent 离线阈值：\(agentOfflineMin) 分钟",
                        value: $agentOfflineMin, in: 5...120, step: 5)
                Stepper("响应超时阈值：\(responseTimeoutSec) 秒",
                        value: $responseTimeoutSec, in: 1...30)
                Stepper("Token 异常阈值：\(tokenAlertPct)%",
                        value: $tokenAlertPct, in: 100...500, step: 10)
            }
        }
        .formStyle(.grouped)
        .padding(.vertical, 8)
    }
}

// MARK: - About

private struct AboutPane: View {
    @EnvironmentObject var viewModel: AppViewModel

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 52))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.indigo)

            Text("OpenClaw Monitor")
                .font(.title2).fontWeight(.bold)

            Text("Version 1.0")
                .font(.subheadline).foregroundStyle(.secondary)

            Text("监控你的 OpenClaw Agent 全部状态")
                .font(.callout).foregroundStyle(.secondary)

            Divider().frame(width: 200)

            if let path = viewModel.configFilePath {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    Text(path)
                        .font(.caption2).foregroundStyle(.secondary)
                        .fontDesign(.monospaced)
                        .lineLimit(1).truncationMode(.middle)
                }
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle").foregroundStyle(.yellow)
                    Text("未检测到配置文件")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }

            Link("github.com/xmanrui/OpenClaw-bot-review",
                 destination: URL(string: "https://github.com/xmanrui/OpenClaw-bot-review")!)
                .font(.caption)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
