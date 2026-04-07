import UserNotifications

struct NotificationScheduler {

    static func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    // MARK: - Hydration Reminders

    static func scheduleHydrationReminders() {
        let center = UNUserNotificationCenter.current()

        // Remove existing hydration notifications
        center.removePendingNotificationRequests(withIdentifiers:
            (9...20).map { "hydration-\($0)" }
        )

        let messages = [
            "Time for a glass of water. GLP-1s suppress thirst.",
            "Stay hydrated. Your body needs it more than you think.",
            "Quick water check. Have you had a glass in the last hour?",
            "Hydration reminder. Sip, don't chug.",
        ]

        // Every 2 hours from 9am to 8pm
        for hour in stride(from: 9, through: 20, by: 2) {
            let content = UNMutableNotificationContent()
            content.title = "Hydration"
            content.body = messages.randomElement() ?? messages[0]
            content.sound = .default

            var dateComponents = DateComponents()
            dateComponents.hour = hour
            dateComponents.minute = 0

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let request = UNNotificationRequest(identifier: "hydration-\(hour)", content: content, trigger: trigger)

            center.add(request)
        }
    }

    // MARK: - Protein Check-in

    static func scheduleProteinReminder(hour: Int = 16) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["protein-check"])

        let content = UNMutableNotificationContent()
        content.title = "Protein Check"
        content.body = "How's your protein intake today? Open Mira to see where you stand."
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "protein-check", content: content, trigger: trigger)

        center.add(request)
    }

    // MARK: - Meal Reminder

    static func scheduleMealReminder(title: String, body: String, hour: Int, minute: Int, identifier: String) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        center.add(request)
    }

    // MARK: - Clear All

    static func clearAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
