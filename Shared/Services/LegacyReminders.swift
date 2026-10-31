import UserNotifications

/// Anything that can drop scheduled notifications by identifier. The system
/// center does; tests pass a spy.
protocol PendingNotificationRemoving {
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
}

extension UNUserNotificationCenter: PendingNotificationRemoving {}

/// Builds before 1.1 let you switch on two repeating reminders: a daily "Time
/// for a few balls" and a weekly warm-up. 1.1 deleted the screen that turned
/// them off, but iOS keeps a scheduled notification across an update, so anyone
/// who had them on would be reminded for ever with no way to stop it from
/// inside the app. This is the other half of that deletion.
enum LegacyReminders {
    static let identifiers = ["duprIQ.dailyReminder", "duprIQ.matchWarmUpReminder"]

    static func cancel(on center: any PendingNotificationRemoving = UNUserNotificationCenter.current()) {
    }
}
