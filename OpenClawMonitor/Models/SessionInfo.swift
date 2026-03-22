import Foundation

struct SessionInfo: Identifiable, Codable {
    let id: String
    let agentId: String
    let type: SessionType
    let platform: String
    let userName: String?
    let channelName: String?
    var tokens: Int
    var messages: Int
    var lastActive: Date
    var status: SessionStatus

    var displayTarget: String {
        switch type {
        case .dm:   return userName ?? "Unknown User"
        case .group, .cron: return channelName ?? "Unknown Channel"
        }
    }

    var typeIcon: String {
        switch type {
        case .dm:    return "person.fill"
        case .group: return "person.2.fill"
        case .cron:  return "clock.fill"
        }
    }

    var typeLabel: String {
        switch type {
        case .dm:    return "DM"
        case .group: return "Group"
        case .cron:  return "Cron"
        }
    }

    var tokensFormatted: String {
        tokens >= 1000 ? String(format: "%.1fk", Double(tokens) / 1000) : "\(tokens)"
    }
}

enum SessionType: String, Codable, CaseIterable {
    case dm, group, cron
}

enum SessionStatus: String, Codable {
    case active, idle, inactive

    var label: String {
        switch self {
        case .active:   return "活跃"
        case .idle:     return "空闲"
        case .inactive: return "不活跃"
        }
    }
}
