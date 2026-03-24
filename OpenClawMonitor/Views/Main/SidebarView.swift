import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable {
    case agents      = "Agents"
    case models      = "Models"
    case sessions    = "Sessions"
    case statistics  = "Statistics"
    case skills      = "Skills"
    case alerts      = "Alerts"
    case cronJobs    = "Cron Jobs"
    case pixelOffice = "Pixel Office"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .agents:      return "person.2.fill"
        case .models:      return "cpu"
        case .sessions:    return "bubble.left.and.bubble.right"
        case .statistics:  return "chart.bar.xaxis"
        case .skills:      return "bolt.fill"
        case .alerts:      return "bell.badge"
        case .cronJobs:    return "clock.badge"
        case .pixelOffice: return "gamecontroller"
        }
    }
}

struct SidebarView: View {
    @Binding var selection: SidebarItem?
    @EnvironmentObject var viewModel: AppViewModel

    var body: some View {
        List(SidebarItem.allCases, selection: $selection) { item in
            HStack {
                Label(item.rawValue, systemImage: item.icon)
                    .symbolRenderingMode(.hierarchical)
                Spacer()
                // Show active alert count badge on Alerts item
                if item == .alerts && viewModel.activeAlertCount > 0 {
                    Text("\(viewModel.activeAlertCount)")
                        .font(.caption2).fontWeight(.bold)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(.red, in: Capsule())
                        .foregroundStyle(.white)
                }
            }
            .tag(item)
        }
        .listStyle(.sidebar)
        .navigationTitle("OpenClaw Monitor")
    }
}
