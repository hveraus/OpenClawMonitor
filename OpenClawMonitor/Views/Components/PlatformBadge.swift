import SwiftUI

struct PlatformBadge: View {
    let platform: String

    var body: some View {
        Text(displayName)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.18), in: Capsule())
            .foregroundStyle(color)
    }

    private var displayName: String {
        switch platform.lowercased() {
        case "feishu", "lark": return "飞书"
        case "discord":        return "Discord"
        case "slack":          return "Slack"
        case "telegram":       return "Telegram"
        case "wechat":         return "微信"
        default:               return platform.capitalized
        }
    }

    private var color: Color {
        switch platform.lowercased() {
        case "feishu", "lark": return .blue
        case "discord":        return Color(red: 0.35, green: 0.40, blue: 0.90)
        case "slack":          return .purple
        case "telegram":       return .cyan
        case "wechat":         return .green
        default:               return .secondary
        }
    }
}
