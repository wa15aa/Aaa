import Foundation
import UserNotifications
import SteadyCore

/// 本地通知：每习惯 1 条自定义时间每日重复提醒（MVP_SPEC §3.4）。
/// 文案非套路："X 还亮着，点一下就好"。
enum NotificationManager {

    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    /// 为习惯调度（或取消）每日提醒。hour/minute 为 nil 时取消。
    static func scheduleReminder(habitId: UUID, name: String, hour: Int?, minute: Int?) {
        let center = UNUserNotificationCenter.current()
        let id = "habit-\(habitId.uuidString)"
        center.removePendingNotificationRequests(withIdentifiers: [id])
        guard let hour = hour, let minute = minute else { return }

        let content = UNMutableNotificationContent()
        content.title = name
        content.body = "Still open — one tap to check in. Missing one day is fine."
        content.sound = .default

        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let req = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        center.add(req, withCompletionHandler: nil)
    }

    static func cancelReminder(habitId: UUID) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["habit-\(habitId.uuidString)"])
    }
}
