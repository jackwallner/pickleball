import Foundation

/// How much evidence a number needs before the app is allowed to show it.
enum MasteryThreshold {
    /// Graded balls in one principle before a percentage is shown.
    static let sample = 5
    /// Balls in one calendar day before that day counts toward the streak.
    static let ballsForPracticeDay = 5
}

/// What "Your game" may say about one principle.
enum MasterySignal: Equatable, Sendable {
    case new
    case building(answered: Int)
    case measured(Double)
}

/// A finished run of points. Kept for Pro's history.
struct RallyRecord: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let date: Date
    let pointsWon: Int
    let pointsLost: Int
    let answered: Int
    let correct: Int
}

/// One named trap and how often it has caught this player.
struct MistakeTally: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let phase: String
    var misses: Int
    /// Focus balls on this trap answered correctly since the last miss.
    var fixes: Int
    var lastMissed: Date

    var isOpen: Bool { misses > fixes }
    var title: String { MistakeCatalog.title(for: id) }
}

/// Everything the app remembers about how someone plays.
///
/// One Codable value under one key, rather than a dozen loose defaults: the
/// whole model is small, and a single blob cannot half-save.
struct MasteryState: Codable, Equatable, Sendable {
    var attempts: [String: Int] = [:]
    var correct: [String: Int] = [:]
    var phaseAttempts: [String: Int] = [:]
    var phaseCorrect: [String: Int] = [:]
    var mistakes: [MistakeTally] = []
    var rallies: [RallyRecord] = []
    var totalAnswered = 0
    var streak = 0
    var lastPracticeDay: Date?
    var ballsToday = 0
    var ballsDay: Date?
}

/// Per-principle mastery, named traps, the streak, and Pro's rally history.
@MainActor
final class MasteryStore: ObservableObject {
    static let shared = MasteryStore()

    static let maxRallies = 50
    private static let key = "mastery.v1"

    @Published private(set) var state: MasteryState

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        state = Self.load(from: defaults)
        rollOverIfNeeded()
    }

    func reload() {
        state = Self.load(from: defaults)
        rollOverIfNeeded()
    }

    // MARK: - Recording

    /// One graded ball. `focus` is the trap this ball was generated to test,
    /// when it was a focus ball.
    func record(_ question: DrillQuestion, picked: Int?, focus: String? = nil, on date: Date = .now) {
        let wasCorrect = picked == question.answerIndex
        let phase = question.position.phase.rawValue
        state.phaseAttempts[phase, default: 0] += 1
        if wasCorrect { state.phaseCorrect[phase, default: 0] += 1 }
        if let family = Principle.family(forVerdict: question.verdict.principle) {
            state.attempts[family.rawValue, default: 0] += 1
            if wasCorrect { state.correct[family.rawValue, default: 0] += 1 }
        }
        state.totalAnswered += 1

        if wasCorrect, let focus, let index = state.mistakes.firstIndex(where: { $0.id == focus }) {
            state.mistakes[index].fixes = min(state.mistakes[index].misses, state.mistakes[index].fixes + 1)
        }
        if !wasCorrect, let picked, let shot = question.options[safe: picked],
           let pattern = MistakeCatalog.pattern(for: shot, in: question.position) {
            recordMistake(pattern, on: date)
        }
        countTowardToday(date)
        persist()
    }

    func recordRally(won: Int, lost: Int, answered: Int, correct: Int, on date: Date = .now) {
        guard answered > 0 else { return }
        state.rallies.insert(RallyRecord(
            id: UUID(), date: date, pointsWon: won, pointsLost: lost,
            answered: answered, correct: correct
        ), at: 0)
        if state.rallies.count > Self.maxRallies {
            state.rallies.removeLast(state.rallies.count - Self.maxRallies)
        }
        persist()
    }

    private func recordMistake(_ pattern: MistakePattern, on date: Date) {
        if let index = state.mistakes.firstIndex(where: { $0.id == pattern.id }) {
            state.mistakes[index].misses += 1
            // A fresh miss reopens the trap: earlier fixes no longer prove it is solved.
            state.mistakes[index].fixes = 0
            state.mistakes[index].lastMissed = date
        } else {
            state.mistakes.append(MistakeTally(
                id: pattern.id, phase: pattern.phase, misses: 1, fixes: 0, lastMissed: date
            ))
        }
        state.mistakes.sort { ($0.misses, $0.lastMissed) > ($1.misses, $1.lastMissed) }
    }

    // MARK: - Reads

    func signal(for principle: Principle) -> MasterySignal {
        let tried = state.attempts[principle.rawValue] ?? 0
        if tried == 0 { return .new }
        if tried < MasteryThreshold.sample { return .building(answered: tried) }
        return .measured(Double(state.correct[principle.rawValue] ?? 0) / Double(tried))
    }

    /// Mistakes ranked by how often they have cost a point.
    var rankedMistakes: [MistakeTally] { state.mistakes }

    var openMistakes: [MistakeTally] { state.mistakes.filter(\.isOpen) }

    var weakestPhase: RallyPhase? {
        RallyPhase.allCases
            .filter { (state.phaseAttempts[$0.rawValue] ?? 0) >= MasteryThreshold.sample }
            .min { accuracy($0) < accuracy($1) }
    }

    private func accuracy(_ phase: RallyPhase) -> Double {
        let tried = state.phaseAttempts[phase.rawValue] ?? 0
        guard tried > 0 else { return 1 }
        return Double(state.phaseCorrect[phase.rawValue] ?? 0) / Double(tried)
    }

    /// What the next run of points should lean on: the traps still catching
    /// this player first, then their weakest phase, then where their level
    /// says to start.
    func focus(for level: ExperienceLevel) -> [RallyFocus] {
        var focus = openMistakes.prefix(3).compactMap { tally in
            RallyPhase(rawValue: tally.phase).map { RallyFocus(phase: $0, mistakeID: tally.id) }
        }
        if let weakest = weakestPhase, !focus.contains(where: { $0.phase == weakest }) {
            focus.append(RallyFocus(phase: weakest, mistakeID: nil))
        }
        if focus.isEmpty {
            focus = level.starterPhases.map { RallyFocus(phase: $0, mistakeID: nil) }
        }
        return focus
    }

    var streak: Int { state.streak }
    var totalAnswered: Int { state.totalAnswered }
    var ballsToday: Int { state.ballsToday }
    var rallies: [RallyRecord] { state.rallies }

    // MARK: - Streak

    private func countTowardToday(_ date: Date) {
        let today = Calendar.current.startOfDay(for: date)
        if let day = state.ballsDay, Calendar.current.isDate(day, inSameDayAs: today) {
            state.ballsToday += 1
        } else {
            state.ballsDay = today
            state.ballsToday = 1
        }
        if state.ballsToday == MasteryThreshold.ballsForPracticeDay {
            updateStreak(for: today)
        }
    }

    private func updateStreak(for today: Date) {
        let calendar = Calendar.current
        guard let last = state.lastPracticeDay else {
            state.streak = 1
            state.lastPracticeDay = today
            return
        }
        if calendar.isDate(last, inSameDayAs: today) { return }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: last), to: today).day ?? 0
        state.streak = days == 1 ? state.streak + 1 : 1
        state.lastPracticeDay = today
    }

    /// A streak whose last day is before yesterday is over, even if no ball has
    /// been played since to reset it.
    func rollOverIfNeeded(now: Date = .now) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        if let day = state.ballsDay, !calendar.isDate(day, inSameDayAs: today) {
            state.ballsToday = 0
            state.ballsDay = today
        }
        if let last = state.lastPracticeDay,
           let gap = calendar.dateComponents([.day], from: calendar.startOfDay(for: last), to: today).day,
           gap > 1, state.streak != 0 {
            state.streak = 0
        }
    }

    // MARK: - Persistence

    private func persist() {
        if let data = try? JSONEncoder().encode(state) {
            defaults.set(data, forKey: Self.key)
        }
    }

    private static func load(from defaults: UserDefaults) -> MasteryState {
        guard let data = defaults.data(forKey: key),
              let state = try? JSONDecoder().decode(MasteryState.self, from: data)
        else { return MasteryState() }
        return state
    }

    func load(_ state: MasteryState) {
        self.state = state
        persist()
    }

    func resetForTesting() {
        state = MasteryState()
        defaults.removeObject(forKey: Self.key)
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
