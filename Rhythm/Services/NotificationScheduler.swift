import Foundation
import UserNotifications

final class NotificationScheduler {
    func authorizationGranted() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
            || settings.authorizationStatus == .ephemeral
    }

    func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            return false
        }
    }

    func scheduleMorningAnchor(hour: Int = 7, minute: Int = 15) async {
        let content = UNMutableNotificationContent()
        content.title = "Step outside before the feeds"
        content.body = "Five to ten minutes of outdoor light anchors tonight's sleep window."
        content.sound = .default
        content.categoryIdentifier = "RHYTHM_MORNING_LIGHT"

        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: "rhythm.morning-light", content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }

    func scheduleDownshift(hour: Int = 21, minute: Int = 0) async {
        let content = UNMutableNotificationContent()
        content.title = "Biological sunset"
        content.body = "Dim lights, hide novelty apps, and set tomorrow's first move."
        content.sound = .default
        content.categoryIdentifier = "RHYTHM_DOWNSHIFT"

        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: "rhythm.downshift", content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }

    func scheduleBatchDelivery(at date: Date, heldCount: Int) async {
        let content = UNMutableNotificationContent()
        content.title = "Notification batch ready"
        content.body = "\(heldCount) held alerts are ready for one intentional check."
        content.sound = .default
        content.categoryIdentifier = "RHYTHM_BATCH"

        let triggerDate = max(date.timeIntervalSinceNow, 60)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: triggerDate, repeats: false)
        let request = UNNotificationRequest(identifier: "rhythm.notification-batch", content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }

    func scheduleBreathingReminder(in seconds: TimeInterval = 90) async {
        let content = UNMutableNotificationContent()
        content.title = "Reset complete"
        content.body = "Check your body before reopening the loop."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(5, seconds), repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }

    func scheduleGateCheckIn(intent: GateIntentKind) async {
        let content = UNMutableNotificationContent()
        content.title = "App Gate check-in"
        content.body = "\(intent.title) window is complete. Close the loop or choose a reset."
        content.sound = .default
        content.categoryIdentifier = "RHYTHM_APP_GATE"

        let seconds = TimeInterval(max(intent.durationMinutes * 60, 60))
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        let request = UNNotificationRequest(identifier: "rhythm.app-gate", content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }

    func cancelGateCheckIn() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["rhythm.app-gate"])
    }
}
