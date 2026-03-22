import Foundation
import UserNotifications

/// Wraps UNUserNotificationCenter for sending local alert notifications.
@MainActor
final class NotificationService {

    static let shared = NotificationService()
    private init() {}

    // MARK: - Permission

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { granted, error in
            if let error { print("[NotificationService] permission error: \(error)") }
        }
    }

    // MARK: - Send

    /// Sends a macOS notification for Error / Warning alerts.
    /// Info alerts are recorded in the UI only (no system notification per §3.8.1).
    func send(alert: AlertItem) {
        guard alert.type.sendsNotification else { return }

        let content = UNMutableNotificationContent()
        content.title = "OpenClaw Monitor — \(alert.type.label)"
        content.body  = alert.message
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: alert.id.uuidString,
            content: content,
            trigger: nil   // deliver immediately
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error { print("[NotificationService] send error: \(error)") }
        }
    }

    // MARK: - Badge

    func updateBadge(count: Int) {
        UNUserNotificationCenter.current().setBadgeCount(count) { _ in }
    }
}
