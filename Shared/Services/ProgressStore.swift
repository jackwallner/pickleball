import Foundation

/// Per-phase accuracy plus a daily streak.
///
/// Accuracy by phase is the whole point of tracking anything here: a player
/// who is 90% on dinks and 40% in transition needs to be sent to transition,
/// and that recommendation is the thing a drills app can offer that a video
/// library cannot.
@MainActor
final class ProgressStore: ObservableObject {
    static let shared = ProgressStore()

    @Published private(set) var attempts: [String: Int] = [:]
    @Published private(set) var correct: [String: Int] = [:]
    @Published private(set) var streak: Int = 0
    @Published private(set) var lastPracticeDay: Date?
    @Published private(set) var totalAnswered: Int = 0

    private let defaults: UserDefaults
    private enum Key {
        static let attempts = "progress.attempts"
        static let correct = "progress.correct"
        static let streak = "progress.streak"
        static let lastDay = "progress.lastDay"
        static let total = "progress.total"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        attempts = defaults.dictionary(forKey: Key.attempts) as? [String: Int] ?? [:]
        correct = defaults.dictionary(forKey: Key.correct) as? [String: Int] ?? [:]
        streak = defaults.integer(forKey: Key.streak)
        lastPracticeDay = defaults.object(forKey: Key.lastDay) as? Date
        totalAnswered = defaults.integer(forKey: Key.total)
    }

    func record(phase: RallyPhase, wasCorrect: Bool, on date: Date = .now) {
        let key = phase.rawValue
        attempts[key, default: 0] += 1
        if wasCorrect { correct[key, default: 0] += 1 }
        totalAnswered += 1
        updateStreak(for: date)
        persist()
    }

    func accuracy(for phase: RallyPhase) -> Double? {
        let tried = attempts[phase.rawValue] ?? 0
        guard tried > 0 else { return nil }
        return Double(correct[phase.rawValue] ?? 0) / Double(tried)
    }

    func attemptCount(for phase: RallyPhase) -> Int { attempts[phase.rawValue] ?? 0 }

    /// The phase to send someone to next: worst accuracy among phases they have
    /// actually tried enough times for the number to mean anything, otherwise
    /// the first phase they have not touched.
    var weakestPhase: RallyPhase? {
        let tried = RallyPhase.allCases.filter { attemptCount(for: $0) >= 5 }
        if let worst = tried.min(by: { (accuracy(for: $0) ?? 1) < (accuracy(for: $1) ?? 1) }) {
            return worst
        }
        return RallyPhase.allCases.first { attemptCount(for: $0) == 0 }
    }

    private func updateStreak(for date: Date) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: date)
        guard let last = lastPracticeDay.map({ calendar.startOfDay(for: $0) }) else {
            streak = 1
            lastPracticeDay = today
            return
        }
        if calendar.isDate(last, inSameDayAs: today) { return }
        let days = calendar.dateComponents([.day], from: last, to: today).day ?? 0
        streak = days == 1 ? streak + 1 : 1
        lastPracticeDay = today
    }

    private func persist() {
        defaults.set(attempts, forKey: Key.attempts)
        defaults.set(correct, forKey: Key.correct)
        defaults.set(streak, forKey: Key.streak)
        defaults.set(lastPracticeDay, forKey: Key.lastDay)
        defaults.set(totalAnswered, forKey: Key.total)
    }

    func resetForTesting() {
        attempts = [:]; correct = [:]; streak = 0; lastPracticeDay = nil; totalAnswered = 0
        persist()
    }
}
