import SwiftUI
import UserNotifications

/// User-configurable app settings, persisted in UserDefaults.
/// Appearance defaults to the warm light theme regardless of the device style.
@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    enum Appearance: String, CaseIterable, Identifiable {
        case light, dark, system

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .light: return "Light"
            case .dark: return "Dark"
            case .system: return "Match Device"
            }
        }

        var colorScheme: ColorScheme? {
            switch self {
            case .light: return .light
            case .dark: return .dark
            case .system: return nil
            }
        }
    }

    enum MatchWarmUpDay: Int, CaseIterable, Identifiable {
        case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday

        var id: Int { rawValue }

        var displayName: String {
            switch self {
            case .sunday: return "Sunday"
            case .monday: return "Monday"
            case .tuesday: return "Tuesday"
            case .wednesday: return "Wednesday"
            case .thursday: return "Thursday"
            case .friday: return "Friday"
            case .saturday: return "Saturday"
            }
        }
    }

    private enum Keys {
        static let appearance = "settings.appearance"
        static let haptics = "settings.haptics"
        static let sound = "settings.sound"
        static let celebrations = "settings.celebrations"
        static let reminderEnabled = "settings.reminderEnabled"
        static let reminderHour = "settings.reminderHour"
        static let reminderMinute = "settings.reminderMinute"
        // These four carried `gameNight` values in the app this shell came
        // from, with a comment explaining that renaming a key forgets a setting
        // rather than migrating it. That reasoning does not transfer: DUPR IQ
        // has not shipped, so there is no install anywhere holding the old
        // spelling. Once 1.0 is out these become as frozen as the comment said.
        static let matchWarmUpReminderEnabled = "settings.matchWarmUpEnabled"
        static let matchWarmUpDay = "settings.matchWarmUpDay"
        static let matchWarmUpHour = "settings.matchWarmUpHour"
        static let matchWarmUpMinute = "settings.matchWarmUpMinute"
    }

    private static let reminderID = "duprIQ.dailyReminder"
    /// Same rule as the keys above: frozen from 1.0 onward, because renaming it
    /// would leave already-scheduled requests pending forever with nothing able
    /// to cancel them. Safe to have set now, pre-release.
    private static let matchWarmUpReminderID = "duprIQ.matchWarmUpReminder"

    @Published var appearance: Appearance {
        didSet { defaults.set(appearance.rawValue, forKey: Keys.appearance) }
    }

    @Published var hapticsEnabled: Bool {
        didSet { defaults.set(hapticsEnabled, forKey: Keys.haptics) }
    }

    @Published var soundEnabled: Bool {
        didSet { defaults.set(soundEnabled, forKey: Keys.sound) }
    }

    /// Confetti, the full-screen flash, and the streak banners.
    ///
    /// Off by default for a working electrician studying at night. Haptics and
    /// sound keep their own switches; this one is only the visual celebration.
    @Published var celebrationsEnabled: Bool {
        didSet { defaults.set(celebrationsEnabled, forKey: Keys.celebrations) }
    }

    @Published var reminderEnabled: Bool {
        didSet {
            defaults.set(reminderEnabled, forKey: Keys.reminderEnabled)
            if reminderEnabled {
                requestPermissionAndSchedule()
            } else {
                cancelReminder()
            }
        }
    }

    /// True when the player asked for a reminder but iOS notifications are off
    /// for the app. Without this the toggle just silently flips back, which
    /// looks like the app is broken.
    @Published var reminderPermissionDenied = false

    @Published var reminderTime: Date {
        didSet {
            let parts = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
            defaults.set(parts.hour ?? 9, forKey: Keys.reminderHour)
            defaults.set(parts.minute ?? 0, forKey: Keys.reminderMinute)
            if reminderEnabled { scheduleReminder() }
        }
    }

    @Published var matchWarmUpReminderEnabled: Bool {
        didSet {
            defaults.set(matchWarmUpReminderEnabled, forKey: Keys.matchWarmUpReminderEnabled)
            if matchWarmUpReminderEnabled {
                requestPermissionAndScheduleMatchWarmUp()
            } else {
                cancelMatchWarmUpReminder()
            }
        }
    }

    @Published var matchWarmUpDay: MatchWarmUpDay {
        didSet {
            defaults.set(matchWarmUpDay.rawValue, forKey: Keys.matchWarmUpDay)
            if matchWarmUpReminderEnabled { scheduleMatchWarmUpReminder() }
        }
    }

    @Published var matchWarmUpReminderTime: Date {
        didSet {
            let parts = Calendar.current.dateComponents([.hour, .minute], from: matchWarmUpReminderTime)
            defaults.set(parts.hour ?? 17, forKey: Keys.matchWarmUpHour)
            defaults.set(parts.minute ?? 0, forKey: Keys.matchWarmUpMinute)
            if matchWarmUpReminderEnabled { scheduleMatchWarmUpReminder() }
        }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        appearance = Appearance(rawValue: defaults.string(forKey: Keys.appearance) ?? "") ?? .light
        hapticsEnabled = defaults.object(forKey: Keys.haptics) as? Bool ?? true
        soundEnabled = defaults.object(forKey: Keys.sound) as? Bool ?? true
        celebrationsEnabled = defaults.object(forKey: Keys.celebrations) as? Bool ?? false
        reminderEnabled = defaults.bool(forKey: Keys.reminderEnabled)
        let hour = defaults.object(forKey: Keys.reminderHour) as? Int ?? 9
        let minute = defaults.object(forKey: Keys.reminderMinute) as? Int ?? 0
        reminderTime = Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? Date()
        matchWarmUpReminderEnabled = defaults.bool(forKey: Keys.matchWarmUpReminderEnabled)
        let savedDay = defaults.integer(forKey: Keys.matchWarmUpDay)
        matchWarmUpDay = MatchWarmUpDay(rawValue: savedDay) ?? .thursday
        let warmUpHour = defaults.object(forKey: Keys.matchWarmUpHour) as? Int ?? 17
        let warmUpMinute = defaults.object(forKey: Keys.matchWarmUpMinute) as? Int ?? 0
        matchWarmUpReminderTime = Calendar.current.date(
            from: DateComponents(hour: warmUpHour, minute: warmUpMinute)
        ) ?? Date()
    }

    // MARK: - Daily reminder

    private func requestPermissionAndSchedule() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            Task { @MainActor in
                if granted {
                    self.scheduleReminder()
                } else {
                    self.reminderEnabled = false
                    self.reminderPermissionDenied = true
                }
            }
        }
    }

    private func scheduleReminder() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.reminderID])

        let content = UNMutableNotificationContent()
        content.title = ShellCopy.DailyReminder.title
        content.body = ShellCopy.DailyReminder.body
        content.sound = .default

        var parts = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        parts.second = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: true)
        center.add(UNNotificationRequest(identifier: Self.reminderID, content: content, trigger: trigger))
    }

    private func cancelReminder() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [Self.reminderID])
    }

    // MARK: - Exam warm-up reminder

    private func requestPermissionAndScheduleMatchWarmUp() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            Task { @MainActor in
                if granted {
                    self.scheduleMatchWarmUpReminder()
                } else {
                    self.matchWarmUpReminderEnabled = false
                    self.reminderPermissionDenied = true
                }
            }
        }
    }

    private func scheduleMatchWarmUpReminder() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.matchWarmUpReminderID])

        let content = UNMutableNotificationContent()
        content.title = ShellCopy.MatchWarmUpReminder.title
        content.body = ShellCopy.MatchWarmUpReminder.body
        content.sound = .default
        content.userInfo = [AppNotification.routeKey: AppNotification.matchWarmUpValue]

        let time = Calendar.current.dateComponents([.hour, .minute], from: matchWarmUpReminderTime)
        var parts = DateComponents()
        parts.weekday = matchWarmUpDay.rawValue
        parts.hour = time.hour
        parts.minute = time.minute
        parts.second = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: true)
        center.add(UNNotificationRequest(identifier: Self.matchWarmUpReminderID, content: content, trigger: trigger))
    }

    func cancelMatchWarmUpReminder() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [Self.matchWarmUpReminderID])
    }
}
