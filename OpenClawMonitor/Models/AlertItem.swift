import Foundation

struct AlertItem: Identifiable {
    let id: UUID
    let type: AlertType
    let message: String
    let timestamp: Date
    var status: AlertStatus

    init(type: AlertType, message: String, timestamp: Date = .now, status: AlertStatus = .active) {
        self.id = UUID()
        self.type = type
        self.message = message
        self.timestamp = timestamp
        self.status = status
    }
}

enum AlertType: String, CaseIterable {
    case error, warning, info

    var icon: String {
        switch self {
        case .error:   return "exclamationmark.triangle.fill"
        case .warning: return "exclamationmark.circle.fill"
        case .info:    return "info.circle.fill"
        }
    }

    var label: String {
        switch self {
        case .error:   return "错误"
        case .warning: return "警告"
        case .info:    return "信息"
        }
    }

    /// Whether this type triggers a system notification
    var sendsNotification: Bool {
        switch self {
        case .error, .warning: return true
        case .info:            return false
        }
    }
}

enum AlertStatus: String {
    case active, resolved

    var label: String {
        switch self {
        case .active:   return "活跃"
        case .resolved: return "已解决"
        }
    }
}
