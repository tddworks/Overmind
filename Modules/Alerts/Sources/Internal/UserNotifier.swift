import Foundation
import UserNotifications

/// The `Notifier` port over User Notifications. Asks for permission on the first warning.
struct UserNotifier: Notifier {
    func post(_ warning: Warning) async {
        let center = UNUserNotificationCenter.current()
        guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return }
        let content = UNMutableNotificationContent()
        content.title = warning.title
        content.body = warning.body
        content.sound = .default
        let id = "\(warning.key.limit)-\(warning.key.period.timeIntervalSince1970)"
        try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: nil))
    }
}
