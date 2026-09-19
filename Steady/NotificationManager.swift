import Foundation
import UserNotifications
import SteadyCore

/// 本地通知：每习惯 ≤3 条自定义时间每日重复提醒（W6 功能批②，MVP_SPEC §3.4 扩展）。
/// 文案非套路："X 还亮着，点一下就好"。
enum NotificationManager {

    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    private static func ids(_ habitId: UUID) -> [String] {
        (0..<3).map { "habit-\(habitId.uuidString)-\($0)" }
    }

    /// 批量调度（或清空）每日提醒。times 元素为 (hour, minute)，≤3 条。
    static func scheduleReminders(habitId: UUID, name: String, times: [(hour: Int, minute: Int)]) {
        let center = UNUserNotificationCenter.current()
        let allIds = ids(habitId)
        center.removePendingNotificationRequests(withIdentifiers: allIds)
        for (i, t) in times.prefix(3).enumerated() {
            let content = UNMutableNotificationContent()
            content.title = name
            content.body = "Still open — one tap to check in. Missing one day is fine."
            content.sound = .default
            var comps = DateComponents()
            comps.hour = t.hour
            comps.minute = t.minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            center.add(UNNotificationRequest(identifier: allIds[i], content: content, trigger: trigger),
                       withCompletionHandler: nil)
        }
    }

    /// 兼容旧单提醒接口。
    static func scheduleReminder(habitId: UUID, name: String, hour: Int?, minute: Int?) {
        if let hour = hour, let minute = minute {
            scheduleReminders(habitId: habitId, name: name, times: [(hour, minute)])
        } else {
            scheduleReminders(habitId: habitId, name: name, times: [])
        }
    }

    static func cancelReminder(habitId: UUID) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ids(habitId))
    }
}
