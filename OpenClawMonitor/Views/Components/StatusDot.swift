import SwiftUI

/// A glowing status indicator dot as specified in §3.10.5
struct StatusDot: View {
    enum Status {
        case online, idle, offline, unknown

        var color: Color {
            switch self {
            case .online:  return .green
            case .idle:    return .yellow
            case .offline: return .red
            case .unknown: return Color(.darkGray)
            }
        }
    }

    let status: Status
    var size: CGFloat = 8

    @State private var isPulsing = false

    var body: some View {
        Circle()
            .fill(status.color)
            .frame(width: size, height: size)
            .shadow(color: status.color.opacity(0.85), radius: isPulsing ? 6 : 3)
            .scaleEffect(isPulsing ? 1.15 : 1.0)
            .animation(
                status == .online
                    ? .easeInOut(duration: 1.5).repeatForever(autoreverses: true)
                    : .default,
                value: isPulsing
            )
            .onAppear {
                isPulsing = (status == .online)
            }
            .onChange(of: status) { _, newStatus in
                isPulsing = (newStatus == .online)
            }
    }
}

#Preview {
    HStack(spacing: 12) {
        StatusDot(status: .online)
        StatusDot(status: .idle)
        StatusDot(status: .offline)
        StatusDot(status: .unknown)
    }
    .padding()
    .preferredColorScheme(.dark)
}
