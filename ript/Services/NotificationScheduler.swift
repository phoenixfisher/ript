import Foundation
import UserNotifications

struct NotificationScheduler {
    static func requestAuthorization() async {
        let center = UNUserNotificationCenter.current()
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    static func scheduleDailyReminders() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        let items = reminderItems()

        for (body, hour, minute) in items {
            let content = UNMutableNotificationContent()
            content.title = "Ript"
            content.body = body
            var date = DateComponents()
            date.hour = hour
            date.minute = minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
            center.add(request)
        }
    }

    private static func reminderItems() -> [(String, Int, Int)] {
        let defaults = UserDefaults.standard
        var items: [(String, Int, Int)] = []

        if defaults.bool(forKey: "workoutReminderEnabled", defaultValue: true) {
            items.append(("Win the first 10 seconds.", 6, 0))
        }

        if defaults.bool(forKey: "fuelReminderEnabled", defaultValue: false) {
            items.append(("Fuel the body you are building.", 11, 30))
        }

        if defaults.bool(forKey: "reflectReminderEnabled", defaultValue: true) {
            items.append(("Did you win today?", 22, 30))
        }

        if defaults.bool(forKey: "streakReminderEnabled", defaultValue: false) {
            items.append(("Protect the streak with one action.", 18, 0))
        }

        return items
    }
}

private extension UserDefaults {
    func bool(forKey key: String, defaultValue: Bool) -> Bool {
        guard object(forKey: key) != nil else { return defaultValue }
        return bool(forKey: key)
    }
}
