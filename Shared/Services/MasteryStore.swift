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

/// A date on the player's own clock, with no time and no time zone.
///
/// The streak and today's ball count used to store the start of the day as an
/// instant. Read again after a westward time zone change, New York's midnight
/// is 21:00 the day before in Los Angeles, so yesterday's practice read as two
/// days ago and the streak ended. A date written as year, month and day reads
/// the same in every zone.
struct CalendarDay: Codable, Hashable, Sendable {
    let year: Int
    let month: Int
    let day: Int

    /// The Gregorian date `date` falls on in `calendar`'s time zone, whatever
    /// calendar the device uses (see `MasteryStore.rollOverIfNeeded`).
    init(_ date: Date, in calendar: Calendar) {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        let parts = gregorian.dateComponents([.year, .month, .day], from: date)
        year = parts.year ?? 0
        month = parts.month ?? 0
        day = parts.day ?? 0
    }

    /// Calendar days from this date to `later`, subtracted at noon UTC, which
    /// has no clock changes.
    func days(until later: CalendarDay) -> Int {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0) ?? utc.timeZone
        func noon(_ value: CalendarDay) -> Date? {
            utc.date(from: DateComponents(year: value.year, month: value.month, day: value.day, hour: 12))
        }
        guard let from = noon(self), let to = noon(later) else { return 0 }
        return Int((to.timeIntervalSince(from) / 86_400).rounded())
    }
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
    /// Start of the last practice day as an instant. Still written so an
    /// older build reads a sensible value; `lastPracticeDate` is the truth.
    var lastPracticeDay: Date?
    var ballsToday = 0
    var ballsDay: Date?
    /// The dates themselves. Absent in blobs saved before these fields
    /// existed, which fall back to the instants above, read in the current
    /// zone as before.
    var lastPracticeDate: CalendarDay?
    var ballsDate: CalendarDay?
}

/// Per-principle mastery, named traps, the streak, and Pro's rally history.
@MainActor
final class MasteryStore: ObservableObject {
    static let shared = MasteryStore()

    static let maxRallies = 50
    private static let key = "mastery.v1"

    @Published private(set) var state: MasteryState

    private let defaults: UserDefaults
    private let calendarOverride: Calendar?

    /// Days are counted on the device's calendar. Tests pin one so a zone's
    /// clock changes do not depend on where the runner happens to be.
    private var calendar: Calendar { calendarOverride ?? .current }

    init(defaults: UserDefaults = .standard, calendar: Calendar? = nil) {
        self.defaults = defaults
        calendarOverride = calendar
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
           let pattern = MistakeCatalog.pattern(for: shot, in: question) {
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
    var rankedMistakes: [MistakeTally] { state.mistakes.filter { MistakeCatalog.allIDs.contains($0.id) } }

    /// Retired traps can never be fixed, so they never count as open.
    var openMistakes: [MistakeTally] {
        state.mistakes.filter { $0.isOpen && MistakeCatalog.allIDs.contains($0.id) }
    }

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
            focus = level.starterPhases.map { RallyFocus(phase: $0, mistakeID: nil, isStarter: true) }
        }
        return focus
    }

    var streak: Int { state.streak }
    var totalAnswered: Int { state.totalAnswered }
    var ballsToday: Int { state.ballsToday }
    var rallies: [RallyRecord] { state.rallies }

    // MARK: - Streak

    /// The date today's balls were counted on, and the last practice date.
    /// A blob saved before the date fields has only the instants, read in the
    /// current zone exactly as earlier builds read them.
    private var ballsCountedOn: CalendarDay? {
        state.ballsDate ?? state.ballsDay.map { CalendarDay($0, in: calendar) }
    }

    private var lastPracticed: CalendarDay? {
        state.lastPracticeDate ?? state.lastPracticeDay.map { CalendarDay($0, in: calendar) }
    }

    private func countTowardToday(_ date: Date) {
        let today = CalendarDay(date, in: calendar)
        if ballsCountedOn == today {
            state.ballsToday += 1
        } else {
            state.ballsDate = today
            state.ballsDay = calendar.startOfDay(for: date)
            state.ballsToday = 1
        }
        if state.ballsToday == MasteryThreshold.ballsForPracticeDay {
            updateStreak(for: today, at: date)
        }
    }

    private func updateStreak(for today: CalendarDay, at date: Date) {
        if let last = lastPracticed {
            let days = last.days(until: today)
            if days == 0 { return }
            state.streak = days == 1 ? state.streak + 1 : 1
        } else {
            state.streak = 1
        }
        state.lastPracticeDate = today
        state.lastPracticeDay = calendar.startOfDay(for: date)
    }

    /// Calendar days are counted by date and not by hours. Two starts of day
    /// can be 23 hours apart: where clocks go forward at midnight (Santiago,
    /// Havana, Cairo, Beirut) the day starts at 01:00, and `dateComponents`
    /// calls 01:00 to the next midnight zero days. `CalendarDay` reads each
    /// date's year, month and day and subtracts them at noon UTC, which has no
    /// clock changes, so every zone's rules drop out at once. The dates are
    /// read off the Gregorian calendar whatever the device uses: a lunisolar
    /// calendar numbers its leap month like the month before it, so
    /// consecutive days read 29 days back or 31 ahead at the two ends of it.
    ///
    /// A streak whose last day is before yesterday is over, even if no ball has
    /// been played since to reset it.
    func rollOverIfNeeded(now: Date = .now) {
        let today = CalendarDay(now, in: calendar)
        if let counted = ballsCountedOn, counted != today {
            state.ballsToday = 0
            state.ballsDate = today
            state.ballsDay = calendar.startOfDay(for: now)
        }
        if let last = lastPracticed, last.days(until: today) > 1, state.streak != 0 {
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
