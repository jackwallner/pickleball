import Foundation

/// One item's answering history and its next review date.
///
/// `ProgressStore` already tracks "seen" and "missed" as flat sets, which is
/// enough to sort a daily mix but not enough to schedule anything: a question
/// missed once and then answered right four times still sits in `missedItems`
/// forever. This record carries the counts and the interval, so review can be
/// spaced instead of permanent.
struct PracticeRecord: Codable, Sendable {
    var attempts: Int = 0
    var correct: Int = 0
    var streak: Int = 0
    var lastAnswered: Date = .distantPast
    var dueDate: Date = .distantPast
    var intervalDays: Double = 0
    var ease: Double = 2.5
    var roomID: String = ""
    /// Optional for backward-compatible decoding of records written before
    /// generated daily prompts existed.
    var reviewSuppressed: Bool?

    var accuracy: Double {
        attempts == 0 ? 0 : Double(correct) / Double(attempts)
    }

    var isDue: Bool { dueDate <= Date() }

    /// True while the item still needs work: it has been missed at least once
    /// and has not yet been answered right twice running.
    var needsReview: Bool { reviewSuppressed != true && attempts > correct && streak < 2 }
}

/// A running count of one named mistake.
///
/// Separate from `PracticeRecord` on purpose. A record is about an ITEM, and a
/// generated item is a one-off whose id will never be seen again. A mistake is
/// about a HABIT, and habits are exactly what a candidate needs to unlearn
/// before an exam. Storing the pattern rather than the question is what lets
/// "your misses come back" be true for generated practice without an unbounded
/// dictionary of dead question ids.
struct MistakeTally: Codable, Sendable {
    var pattern: MistakePattern
    /// Outstanding misses. A correct answer on a targeted follow-up works it
    /// back down; at zero the pattern is considered fixed and is dropped.
    var outstanding: Int
    var totalMisses: Int
    var lastMissed: Date
}

/// Per-item practice history, the spaced-repetition queue built on top of it,
/// the mistake-pattern tallies behind targeted practice, and the room-level
/// rollups the stats screen reads.
@MainActor
final class PracticeRecordStore: ObservableObject {
    static let shared = PracticeRecordStore()

    @Published private(set) var records: [String: PracticeRecord]
    /// Named mistakes still outstanding, keyed by `MistakePattern.id`.
    @Published private(set) var mistakes: [String: MistakeTally]
    /// Best timed-challenge score, kept separately because it is a high score
    /// rather than a per-item fact.
    @Published private(set) var bestChallengeScore: Int

    private let defaults: UserDefaults

    private enum Keys {
        static let records = "practice.records"
        static let mistakes = "practice.mistakePatterns"
        static let bestChallenge = "practice.bestChallengeScore"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        bestChallengeScore = defaults.integer(forKey: Keys.bestChallenge)
        if let data = defaults.data(forKey: Keys.records),
           let decoded = try? JSONDecoder().decode([String: PracticeRecord].self, from: data) {
            records = decoded
        } else {
            records = [:]
        }
        if let data = defaults.data(forKey: Keys.mistakes),
           let decoded = try? JSONDecoder().decode([String: MistakeTally].self, from: data) {
            mistakes = decoded
        } else {
            mistakes = [:]
        }
    }

    // MARK: - Mistake patterns

    /// How many outstanding misses a single pattern may bank. Without a cap a
    /// bad afternoon on one shape crowds every other pattern out of targeted
    /// practice for days.
    static let maxOutstandingPerPattern = 5

    func recordMistake(_ pattern: MistakePattern, now: Date = Date()) {
        var tally = mistakes[pattern.id] ?? MistakeTally(
            pattern: pattern, outstanding: 0, totalMisses: 0, lastMissed: now
        )
        // Rewritten rather than kept: the summary copy can improve between
        // releases and the stored one should not be the stale version.
        tally.pattern = pattern
        tally.outstanding = min(tally.outstanding + 1, Self.maxOutstandingPerPattern)
        tally.totalMisses += 1
        tally.lastMissed = now
        mistakes[pattern.id] = tally
        persistMistakes()
    }

    /// A correct answer on a problem that set this trap. Works the pattern off
    /// one at a time so a single lucky pick does not clear a habit.
    func resolveMistake(_ patternID: String) {
        guard var tally = mistakes[patternID] else { return }
        tally.outstanding -= 1
        if tally.outstanding <= 0 {
            mistakes.removeValue(forKey: patternID)
        } else {
            mistakes[patternID] = tally
        }
        persistMistakes()
    }

    /// The patterns targeted practice should aim at, worst first.
    func outstandingMistakes(limit: Int = 4) -> [MistakePattern] {
        mistakes.values
            .sorted { lhs, rhs in
                if lhs.outstanding != rhs.outstanding { return lhs.outstanding > rhs.outstanding }
                return lhs.lastMissed > rhs.lastMissed
            }
            .prefix(limit)
            .map(\.pattern)
    }

    var outstandingMistakeCount: Int {
        mistakes.values.reduce(0) { $0 + $1.outstanding }
    }

    private func persistMistakes() {
        guard let data = try? JSONEncoder().encode(mistakes) else { return }
        defaults.set(data, forKey: Keys.mistakes)
    }

    // MARK: - Recording

    /// Grades one answer. Generated items collapse onto a single per-skill row:
    /// an endless mode mints a new id every question, and storing each one
    /// would grow this dictionary without bound and drown the real items in
    /// the review queue.
    func record(
        itemID: String,
        roomID: String,
        correct: Bool,
        isReviewable: Bool = true,
        now: Date = Date()
    ) {
        let key = RallyPhase.phase(forItemID: itemID).map(\.rawValue) ?? itemID
        let isGenerated = RallyPhase.phase(forItemID: itemID) != nil

        var record = records[key] ?? PracticeRecord()
        record.attempts += 1
        record.roomID = roomID
        record.reviewSuppressed = !isReviewable || isGenerated
        record.lastAnswered = now
        if correct {
            record.correct += 1
            record.streak += 1
        } else {
            record.streak = 0
        }
        // Generated questions never repeat, so scheduling one for review is
        // meaningless. They contribute to accuracy stats only.
        if isReviewable && !isGenerated {
            schedule(&record, correct: correct, now: now)
        }
        records[key] = record
        persist()
    }

    /// SM-2, trimmed to what a drill app needs: a miss resets the interval and
    /// costs ease, a hit multiplies the interval by the current ease.
    private func schedule(_ record: inout PracticeRecord, correct: Bool, now: Date) {
        if correct {
            switch record.streak {
            case 1: record.intervalDays = 1
            case 2: record.intervalDays = 3
            default: record.intervalDays = min(record.intervalDays * record.ease, 180)
            }
            record.ease = min(record.ease + 0.1, 2.8)
        } else {
            record.intervalDays = 0
            record.ease = max(record.ease - 0.2, 1.3)
        }
        record.dueDate = now.addingTimeInterval(record.intervalDays * 86_400)
    }

    func recordChallengeScore(_ score: Int) {
        guard score > bestChallengeScore else { return }
        bestChallengeScore = score
        defaults.set(score, forKey: Keys.bestChallenge)
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        defaults.set(data, forKey: Keys.records)
    }

    // MARK: - Review queue

    /// Item ids that are due for another look, worst first. "Worst" is lowest
    /// accuracy, then longest overdue, so the questions a player keeps getting
    /// wrong surface before the ones they nearly have.
    func reviewQueue(limit: Int = 12) -> [String] {
        records
            .filter { $0.value.needsReview && $0.value.isDue && RallyPhase(rawValue: $0.key) == nil }
            .sorted { lhs, rhs in
                if lhs.value.accuracy != rhs.value.accuracy { return lhs.value.accuracy < rhs.value.accuracy }
                return lhs.value.dueDate < rhs.value.dueDate
            }
            .prefix(limit)
            .map(\.key)
    }

    /// Authored items waiting for another look.
    var dueCount: Int {
        records.filter { $0.value.needsReview && $0.value.isDue && RallyPhase(rawValue: $0.key) == nil }.count
    }

    /// Everything Fix My Mistakes has to work with: the authored questions the
    /// scheduler says are due, plus the outstanding generated mistake patterns
    /// it can mint a fresh targeted problem for.
    var fixableCount: Int { dueCount + outstandingMistakeCount }

    // MARK: - Stats

    struct RoomStat: Identifiable {
        let id: String
        let name: String
        let attempts: Int
        let correct: Int
        var accuracy: Double { attempts == 0 ? 0 : Double(correct) / Double(attempts) }
    }

    var totalAttempts: Int { records.values.reduce(0) { $0 + $1.attempts } }
    var totalCorrect: Int { records.values.reduce(0) { $0 + $1.correct } }
    var overallAccuracy: Double {
        totalAttempts == 0 ? 0 : Double(totalCorrect) / Double(totalAttempts)
    }

    /// Accuracy per room, in library order, skipping rooms never practised.
    func roomStats() -> [RoomStat] {
        DrillLibrary.rooms.compactMap { room in
            let mine = records.values.filter { $0.roomID == room.id }
            let attempts = mine.reduce(0) { $0 + $1.attempts }
            guard attempts > 0 else { return nil }
            return RoomStat(
                id: room.id,
                name: room.name,
                attempts: attempts,
                correct: mine.reduce(0) { $0 + $1.correct }
            )
        }
    }

    /// Accuracy per generated skill. Generated answers all collapse onto one
    /// row per skill, so this is the finest breakdown the store can honestly
    /// report for them: "you are 58% on derating" is actionable in a way that
    /// "you are 71% in Conductors & Ampacity" is not.
    func skillStats() -> [RoomStat] {
        RallyPhase.allCases.compactMap { skill in
            guard let record = records[skill.rawValue], record.attempts > 0 else { return nil }
            return RoomStat(
                id: skill.rawValue,
                name: skill.title,
                attempts: record.attempts,
                correct: record.correct
            )
        }
    }

    /// The room a player is worst at, once there is enough data to mean it.
    func weakestRoom() -> RoomStat? {
        roomStats().filter { $0.attempts >= 5 }.min { $0.accuracy < $1.accuracy }
    }

    func resetAll() {
        records = [:]
        mistakes = [:]
        bestChallengeScore = 0
        defaults.removeObject(forKey: Keys.records)
        defaults.removeObject(forKey: Keys.mistakes)
        defaults.removeObject(forKey: Keys.bestChallenge)
    }
}
