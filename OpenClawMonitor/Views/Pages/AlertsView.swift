import SwiftUI

struct AlertsView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var filterType: AlertTypeFilter = .all

    private enum AlertTypeFilter: String, CaseIterable, Identifiable {
        case all     = "全部"
        case error   = "错误"
        case warning = "警告"
        case info    = "信息"
        var id: String { rawValue }
    }

    private var filtered: [AlertItem] {
        switch filterType {
        case .all:     return viewModel.alerts
        case .error:   return viewModel.alerts.filter { $0.type == .error }
        case .warning: return viewModel.alerts.filter { $0.type == .warning }
        case .info:    return viewModel.alerts.filter { $0.type == .info }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Filter strip ───────────────────────────────────────────────
            HStack(spacing: 12) {
                Picker("筛选", selection: $filterType) {
                    ForEach(AlertTypeFilter.allCases) { t in
                        Text(t.rawValue).tag(t)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 320)

                Spacer()

                let active = viewModel.activeAlertCount
                if active > 0 {
                    Label("\(active) 条待处理", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption).foregroundStyle(.yellow)
                        .symbolRenderingMode(.hierarchical)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            Divider()

            // ── Alert list ─────────────────────────────────────────────────
            List {
                ForEach(filtered) { alert in
                    AlertRow(alert: alert)
                        .listRowBackground(Color.clear)
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
            .animation(.easeInOut(duration: 0.2), value: filterType)
        }
        .background(Color(.windowBackgroundColor))
    }
}

// MARK: - Alert row

private struct AlertRow: View {
    let alert: AlertItem

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: alert.type.icon)
                .font(.title3)
                .foregroundStyle(iconColor)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(alert.message)
                    .font(.subheadline)
                    .foregroundStyle(alert.status == .resolved ? .secondary : .primary)
                    .lineLimit(2)

                Text(alert.timestamp, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            // Status badge
            Text(alert.status.label)
                .font(.caption2).fontWeight(.semibold)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(statusBadgeColor, in: Capsule())
                .foregroundStyle(statusTextColor)
        }
        .padding(.vertical, 6)
        .opacity(alert.status == .resolved ? 0.55 : 1.0)
    }

    private var iconColor: Color {
        switch alert.type {
        case .error:   return .red
        case .warning: return .yellow
        case .info:    return .blue
        }
    }

    private var statusBadgeColor: Color {
        alert.status == .active ? iconColor.opacity(0.15) : Color.primary.opacity(0.08)
    }

    private var statusTextColor: Color {
        alert.status == .active ? iconColor : .secondary
    }
}
