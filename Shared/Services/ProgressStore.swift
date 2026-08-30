import Foundation

/// How much evidence a phase percentage needs before it is allowed to look
/// like a measurement rather than a coin flip.
enum ProgressThreshold {
    /// Balls in one phase before an accuracy is shown as a number.
    static let sampleForAccuracy = 5
    /// Balls in one calendar day before that day counts toward the streak.
    /// One tap is not a practice day, and a streak that starts on one tap is
    /// engagement theatre rather than a measurement of a habit.
    static let ballsForPracticeDay = 5
}

/// What the UI is allowed to say about a phase, given how much has been
/// answered in it. Keeps "0% after one ball" off the lobby.
enum PhaseSignal: Equatable, Sendable {
    case untried
    case building(answered: Int, needed: Int)
    case measured(Double)

    var isMeasured: Bool { if case .measured = self { return true }; return false }
}

/// One finished session, kept so Pro can show practice history rather than a
/// single lifetime percentage.
struct SessionRecord: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let date: Date
    /// `nil` means the mixed rally.
    let phase: String?
    let answered: Int
    let correct: Int

    var rallyPhase: RallyPhase? { phase.flatMap(RallyPhase.init(rawValue:)) }
    var title: String { rallyPhase?.title ?? "Mixed rally" }
    var accuracy: Double { answered > 0 ? Double(correct) / Double(answered) : 0 }
}

/// A principle the player keeps getting wrong. This is the actionable half of
/// progress: "you are 61% overall" is not a practice plan, "you keep driving
/// the return" is.
struct MissedPrinciple: Codable, Identifiable, Equatable, Sendable {
    let phase: String
    let principle: String
    var count: Int
    var lastSeen: Date

    var id: String { "\(phase)|\(principle)" }
    var rallyPhase: RallyPhase? { RallyPhase(rawValue: phase) }
    var phaseTitle: String { rallyPhase?.title ?? phase }
}

/// Per-phase accuracy, a daily streak, and the practice history behind them.
///
/// Accuracy by phase is the whole point of tracking anything here: a player
/// who is 90% on dinks and 40% in transition needs to be sent to transition,
/// and that recommendation is the thing a drills app can offer that a video
/// library cannot. History and missed principles are what make that
/// recommendation reviewable instead of a single number.
@MainActor
final class ProgressStore: ObservableObject {
    static let shared = ProgressStore()

    static let maxSessions = 50
    static let maxMissedPrinciples = 40

    @Published private(set) var attempts: [String: Int] = [:]
    @Published private(set) var correct: [String: Int] = [:]
    @Published private(set) var streak: Int = 0
    @Published private(set) var lastPracticeDay: Date?
    @Published private(set) var totalAnswered: Int = 0
    @Published private(set) var sessions: [SessionRecord] = []
    @Published private(set) var missed: [MissedPrinciple] = []
    /// Balls answered today, which is what decides whether today is a practice
    /// day. Separate from the free-tier limiter, which Pro users do not have.
    @Published private(set) var ballsToday: Int = 0

    private let defaults: UserDefaults
    private enum Key {
        static let attempts = "progress.attempts"
        static let correct = "progress.correct"
        static let streak = "progress.streak"
        static let lastDay = "progress.lastDay"
        static let total = "progress.total"
        static let sessions = "progress.sessions"
        static let missed = "progress.missed"
        static let ballsToday = "progress.ballsToday"
        static let ballsDay = "progress.ballsDay"
        static let completions = "progress.completions"
        static let totalSessions = "progress.totalSessions"
        static let seenItems = "progress.seenItems"
        static let missedItems = "progress.missedItems"
        static let hasOnboarded = "progress.hasOnboarded"
        static let lastQuickSessionDay = "progress.lastQuickSessionDay"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        reload()
        rollOverIfNeeded()
    }

    func reload() {
        attempts = defaults.dictionary(forKey: Key.attempts) as? [String: Int] ?? [:]
        correct = defaults.dictionary(forKey: Key.correct) as? [String: Int] ?? [:]
        streak = defaults.integer(forKey: Key.streak)
        lastPracticeDay = defaults.object(forKey: Key.lastDay) as? Date
        totalAnswered = defaults.integer(forKey: Key.total)
        sessions = decode([SessionRecord].self, Key.sessions) ?? []
        missed = decode([MissedPrinciple].self, Key.missed) ?? []
        ballsToday = defaults.integer(forKey: Key.ballsToday)
        completions = (defaults.dictionary(forKey: Key.completions) as? [String: Int]) ?? [:]
        totalSessions = defaults.integer(forKey: Key.totalSessions)
        seenItems = Set(defaults.stringArray(forKey: Key.seenItems) ?? [])
        missedItems = Set(defaults.stringArray(forKey: Key.missedItems) ?? [])
    }

    // MARK: - Recording

    func record(
        phase: RallyPhase,
        wasCorrect: Bool,
        principle: String? = nil,
        on date: Date = .now
    ) {
        let key = phase.rawValue
        attempts[key, default: 0] += 1
        if wasCorrect { correct[key, default: 0] += 1 }
        totalAnswered += 1
        if !wasCorrect, let principle { recordMiss(phase: phase, principle: principle, on: date) }
        countTowardToday(date)
        persist()
    }

    func recordSession(phase: RallyPhase?, answered: Int, correct: Int, on date: Date = .now) {
        guard answered > 0 else { return }
        let record = SessionRecord(
            id: UUID(), date: date, phase: phase?.rawValue,
            answered: answered, correct: correct
        )
        sessions.insert(record, at: 0)
        if sessions.count > Self.maxSessions { sessions.removeLast(sessions.count - Self.maxSessions) }
        totalSessions += 1
        persist()
    }

    private func recordMiss(phase: RallyPhase, principle: String, on date: Date) {
        if let index = missed.firstIndex(where: { $0.phase == phase.rawValue && $0.principle == principle }) {
            missed[index].count += 1
            missed[index].lastSeen = date
        } else {
            missed.append(MissedPrinciple(
                phase: phase.rawValue, principle: principle, count: 1, lastSeen: date
            ))
        }
        missed.sort { ($0.count, $0.lastSeen) > ($1.count, $1.lastSeen) }
        if missed.count > Self.maxMissedPrinciples {
            missed.removeLast(missed.count - Self.maxMissedPrinciples)
        }
    }

    // MARK: - Reads

    func accuracy(for phase: RallyPhase) -> Double? {
        let tried = attempts[phase.rawValue] ?? 0
        guard tried > 0 else { return nil }
        return Double(correct[phase.rawValue] ?? 0) / Double(tried)
    }

    func attemptCount(for phase: RallyPhase) -> Int { attempts[phase.rawValue] ?? 0 }

    /// The honest thing to show for a phase. A single answered ball produces a
    /// 0% or a 100%, and a big red 0% next to a footnote saying it does not
    /// mean anything yet is a lie the eye believes before it reads the footnote.
    func signal(for phase: RallyPhase) -> PhaseSignal {
        let tried = attemptCount(for: phase)
        if tried == 0 { return .untried }
        if tried < ProgressThreshold.sampleForAccuracy {
            return .building(answered: tried, needed: ProgressThreshold.sampleForAccuracy)
        }
        return .measured(accuracy(for: phase) ?? 0)
    }

    /// The worst phase among those with enough evidence to call it worst.
    /// `nil` until at least one phase clears the sample threshold.
    var measuredWeakestPhase: RallyPhase? {
        let tried = RallyPhase.allCases.filter {
            attemptCount(for: $0) >= ProgressThreshold.sampleForAccuracy
        }
        return tried.min(by: { (accuracy(for: $0) ?? 1) < (accuracy(for: $1) ?? 1) })
    }

    /// The first phase never practised. Not a weakness measurement, and the UI
    /// must not call it one.
    var untriedPhase: RallyPhase? {
        RallyPhase.allCases.first { attemptCount(for: $0) == 0 }
    }

    /// What to send someone to next, and whether the app has earned the right
    /// to call it their weakest phase.
    var recommendation: (phase: RallyPhase, isMeasured: Bool)? {
        if let weakest = measuredWeakestPhase { return (weakest, true) }
        if let untried = untriedPhase { return (untried, false) }
        return nil
    }

    var recentSessions: [SessionRecord] { sessions }

    var topMissedPrinciples: [MissedPrinciple] { missed }

    // MARK: - Streak

    /// A day counts once the player has answered a real handful of balls, not
    /// on the first tap.
    private func countTowardToday(_ date: Date) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: date)
        let storedDay = defaults.object(forKey: Key.ballsDay) as? Date
        if storedDay == nil || !calendar.isDate(storedDay!, inSameDayAs: today) {
            ballsToday = 0
            defaults.set(today, forKey: Key.ballsDay)
        }
        ballsToday += 1
        if ballsToday == ProgressThreshold.ballsForPracticeDay {
            updateStreak(for: date)
        }
    }

    /// Foregrounding after midnight should update the lobby before the next
    /// answer. Otherwise yesterday's progress survives until the player grades
    /// a ball and the streak guidance is stale on first view.
    func rollOverIfNeeded(now: Date = .now) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        guard let storedDay = defaults.object(forKey: Key.ballsDay) as? Date else {
            if ballsToday != 0 { ballsToday = 0 }
            defaults.set(today, forKey: Key.ballsDay)
            defaults.set(ballsToday, forKey: Key.ballsToday)
            return
        }
        guard !calendar.isDate(storedDay, inSameDayAs: today) else { return }
        ballsToday = 0
        defaults.set(today, forKey: Key.ballsDay)
        defaults.set(0, forKey: Key.ballsToday)
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

    /// Balls still needed today before the day counts. Zero once it does.
    var ballsToPracticeDay: Int {
        max(0, ProgressThreshold.ballsForPracticeDay - ballsToday)
    }


    // MARK: - Authored drills
    //
    // The generated loop above keys everything on `RallyPhase`, because that is
    // what the advisor branches on and what a player can act on. The authored
    // courts need a second, finer memory: which individual drill has been
    // finished, which specific question has been seen, and which ones came back
    // wrong. Those are item ids, not phases, so they get their own maps.
    //
    // They deliberately share one store and one streak. Two stores would mean
    // two streaks, and a player who practised today would have to guess which
    // number the app meant.

    @Published private(set) var completions: [String: Int] = [:]
    @Published private(set) var seenItems: Set<String> = []
    @Published private(set) var missedItems: Set<String> = []
    @Published private(set) var totalSessions: Int = 0

    /// The shell reads the streak under this name. There is only one streak in
    /// the app and it is the phase-practice one, which requires a real handful
    /// of balls rather than a single tap.
    var streakCount: Int { streak }

    var hasOnboarded: Bool {
        get { defaults.bool(forKey: Key.hasOnboarded) }
        set { defaults.set(newValue, forKey: Key.hasOnboarded) }
    }

    func completions(for drillID: String) -> Int { completions[drillID] ?? 0 }

    func courtProgress(_ court: Court) -> Double {
        guard !court.drills.isEmpty else { return 0 }
        let done = court.drills.filter { completions(for: $0.id) > 0 }.count
        return Double(done) / Double(court.drills.count)
    }

    /// A finished authored drill. Note this does NOT bump the streak on its
    /// own: the streak is earned by answering balls, and `record(phase:...)`
    /// is what counts them. A drill you opened and closed is not a practice day.
    func recordSession(drillID: String, now: Date = Date()) {
        completions[drillID, default: 0] += 1
        totalSessions += 1
        defaults.set(completions, forKey: Key.completions)
        defaults.set(totalSessions, forKey: Key.totalSessions)
    }

    /// Item-level memory that feeds Quick Session and Fix My Mistakes: anything
    /// answered wrong comes back first, unseen items come next.
    func recordItem(id: String, correct: Bool) {
        seenItems.insert(id)
        if correct {
            missedItems.remove(id)
        } else {
            missedItems.insert(id)
        }
        defaults.set(Array(seenItems), forKey: Key.seenItems)
        defaults.set(Array(missedItems), forKey: Key.missedItems)
    }

    /// Quick Session is a once-a-day ritual: a fresh mix each day, and once
    /// today's is done the Home card rests until tomorrow rather than handing
    /// back the same questions. Missed items still return on later days.
    func quickSessionCompletedToday(now: Date = Date()) -> Bool {
        guard let last = defaults.object(forKey: Key.lastQuickSessionDay) as? Date else { return false }
        return Calendar.current.isDate(last, inSameDayAs: now)
    }

    func markQuickSessionCompleted(now: Date = Date()) {
        defaults.set(Calendar.current.startOfDay(for: now), forKey: Key.lastQuickSessionDay)
    }

    // MARK: - Persistence

    private func persist() {
        defaults.set(attempts, forKey: Key.attempts)
        defaults.set(correct, forKey: Key.correct)
        defaults.set(streak, forKey: Key.streak)
        defaults.set(lastPracticeDay, forKey: Key.lastDay)
        defaults.set(totalAnswered, forKey: Key.total)
        defaults.set(ballsToday, forKey: Key.ballsToday)
        defaults.set(totalSessions, forKey: Key.totalSessions)
        encode(sessions, Key.sessions)
        encode(missed, Key.missed)
    }

    private func encode<T: Encodable>(_ value: T, _ key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }

    private func decode<T: Decodable>(_ type: T.Type, _ key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    func resetForTesting() {
        attempts = [:]; correct = [:]; streak = 0; lastPracticeDay = nil
        totalAnswered = 0; sessions = []; missed = []; ballsToday = 0
        completions = [:]; totalSessions = 0; seenItems = []; missedItems = []
        defaults.removeObject(forKey: Key.ballsDay)
        defaults.removeObject(forKey: Key.completions)
        defaults.removeObject(forKey: Key.totalSessions)
        defaults.removeObject(forKey: Key.seenItems)
        defaults.removeObject(forKey: Key.missedItems)
        defaults.removeObject(forKey: Key.lastQuickSessionDay)
        persist()
    }

    /// Used by the DEBUG screenshot fixture to install a curated, believable
    /// history. Not reachable from the shipping UI.
    func loadForTesting(
        attempts: [String: Int],
        correct: [String: Int],
        streak: Int,
        totalAnswered: Int,
        sessions: [SessionRecord],
        missed: [MissedPrinciple]
    ) {
        self.attempts = attempts
        self.correct = correct
        self.streak = streak
        self.lastPracticeDay = Calendar.current.startOfDay(for: .now)
        self.totalAnswered = totalAnswered
        self.sessions = sessions
        self.totalSessions = sessions.count
        self.missed = missed
        self.ballsToday = ProgressThreshold.ballsForPracticeDay
        persist()
    }
}
