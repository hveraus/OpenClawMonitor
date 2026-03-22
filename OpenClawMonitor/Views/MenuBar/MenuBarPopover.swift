import SwiftUI

struct MenuBarPopover: View {
    @EnvironmentObject var viewModel: AppViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ── Header ──────────────────────────────────────────────────────
            HStack(spacing: 10) {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.title3)
                    .foregroundStyle(.indigo)
                    .symbolRenderingMode(.hierarchical)
                Text("OpenClaw Monitor")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // ── Gateway Status ───────────────────────────────────────────────
            HStack(spacing: 10) {
                StatusDot(status: viewModel.gatewayStatus.dotStatus, size: 8)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Gateway")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(viewModel.gatewayStatus.label)
                        .font(.callout)
                        .fontWeight(.medium)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            // ── Actions ─────────────────────────────────────────────────────
            VStack(spacing: 2) {
                MenuBarButton(icon: "macwindow", title: "打开主窗口") {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                }
                MenuBarButton(icon: "power", title: "退出", isDestructive: true) {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding(.vertical, 6)
        }
        .frame(width: 280)
        .background(.ultraThinMaterial)
    }
}

private struct MenuBarButton: View {
    let icon: String
    let title: String
    var isDestructive: Bool = false
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(isDestructive ? .red : .primary)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(isHovered ? Color.primary.opacity(0.08) : .clear,
                    in: RoundedRectangle(cornerRadius: 6))
        .onHover { isHovered = $0 }
        .padding(.horizontal, 4)
    }
}
