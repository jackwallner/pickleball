import Foundation

/// The free tier: a fixed number of graded balls per day.
///
/// Chosen over a lifetime cap deliberately. The generator never runs out, so
/// the honest free product is "come back tomorrow", which is also what builds
/// the streak the paid tier is sold against.
@MainActor
final class PracticeLimiter: ObservableObject {
    static let shared = PracticeLimiter()

    static let freeDailyBalls = 15

    @Published private(set) var usedToday: Int = 0

    private let defaults: UserDefaults
    private enum Key {
        static let used = "limiter.usedToday"
        static let day = "limiter.day"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        rollOverIfNeeded()
    }

    /// Pure read. Do not call `rollOverIfNeeded` from here: TodayView reads
    /// this in the view body, and assigning `@Published usedToday` from a
    /// render is an infinite SwiftUI update loop (it hung the test host).
    func remaining(isPro: Bool) -> Int {
        if isPro { return .max }
        return max(0, Self.freeDailyBalls - usedToday)
    }

    func canPractice(isPro: Bool) -> Bool { remaining(isPro: isPro) > 0 }

    func consume(isPro: Bool) {
        guard !isPro else { return }
        rollOverIfNeeded()
        usedToday += 1
        defaults.set(usedToday, forKey: Key.used)
    }

    /// Call from scene phase / consume / init, never from a view body.
    func rollOverIfNeeded(now: Date = .now) {
        let today = Calendar.current.startOfDay(for: now)
        let stored = defaults.object(forKey: Key.day) as? Date
        if stored == nil || !Calendar.current.isDate(stored!, inSameDayAs: today) {
            if usedToday != 0 { usedToday = 0 }
            defaults.set(0, forKey: Key.used)
            defaults.set(today, forKey: Key.day)
        } else {
            let storedUsed = defaults.integer(forKey: Key.used)
            if usedToday != storedUsed { usedToday = storedUsed }
        }
    }

    func resetForTesting() {
        usedToday = 0
        defaults.set(0, forKey: Key.used)
        defaults.removeObject(forKey: Key.day)
    }
}
