import Foundation

enum DailyDrillCategory: String, CaseIterable, Codable, Identifiable, Sendable {
    case softGame
    case transition
    case pressure

    var id: String { rawValue }

    var title: String {
        switch self {
        case .softGame: return "Soft Game"
        case .transition: return "Transition"
        case .pressure: return "Under Pressure"
        }
    }

    var icon: String {
        switch self {
        case .softGame: return "hand.tap.fill"
        case .transition: return "figure.walk"
        case .pressure: return "bolt.fill"
        }
    }
}

struct DailyDrillQuestion: Sendable {
    let category: DailyDrillCategory
    let item: QuickItem
}

struct DailyDrillChallenge: Identifiable, Sendable {
    let day: Date
    let dayKey: String
    let shortDate: String
    let questions: [DailyDrillQuestion]

    var id: String { dayKey }
    var items: [QuickItem] { questions.map(\.item) }
}

/// One shared five-ball set per day.
///
/// Everyone who opens the app on the same day gets the same five, which is what
/// makes the score worth comparing. Two are generated positions seeded off the
/// date so they are identical for every reader without being stored anywhere;
/// three are drawn from the authored pool by the same seed.
enum DailyDrillContent {
    static let questionCount = 5

    /// The day boundary, fixed rather than local.
    ///
    /// "The same five for every member" is a promise, and `Calendar.current`
    /// breaks it: two readers either side of midnight local time get different
    /// sets while their scores claim the same day. The boundary is US Pacific,
    /// so the challenge turns over at midnight for the latest US time zone and
    /// no US reader is more than three hours from their own midnight. Change
    /// this and every stored `dayKey` shifts, so it is effectively permanent.
    static let dayCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles") ?? TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    static let drill = Drill(
        id: "daily-drill",
        title: "Daily Drill",
        subtitle: "Today's shared five-ball challenge",
        kind: .quiz([]),
        isPlus: true
    )

    static func challenge(for day: Date = Date(), calendar: Calendar = dayCalendar) -> DailyDrillChallenge {
        let dayKey = key(for: day, calendar: calendar)
        var rng = SeededGenerator(seed: seed(from: dayKey))

        var questions: [DailyDrillQuestion] = []

        // Two generated positions, seeded so every reader sees the same two.
        let shapes: [(DailyDrillCategory, RallyPhase)] = [
            (.transition, .thirdShot),
            (.softGame, .dinkRally),
        ]
        for (index, shape) in shapes.enumerated() {
            let question = PositionGenerator.question(
                phase: shape.1,
                seed: seed(from: dayKey) &+ UInt64(index &* 104_729)
            )
            var item = EndlessPractice.item(from: question, sourceLabel: "Daily Drill")
            item = QuickItem(
                id: "daily-\(dayKey)-gen-\(index)",
                prompt: item.prompt,
                position: item.position,
                targetOpponent: item.targetOpponent,
                choices: item.choices,
                answerIndex: item.answerIndex,
                explanation: item.explanation,
                steps: item.steps,
                principle: item.principle,
                sourceLabel: "Daily Drill",
                courtID: item.courtID,
                phase: item.phase,
                trackingID: "daily-drill-rollup",
                isReviewable: false,
                mistakes: item.mistakes
            )
            questions.append(DailyDrillQuestion(category: shape.0, item: item))
        }

        // Three authored items, chosen deterministically from the same seed.
        let pool = SessionBuilder.choicePool(includePro: true).sorted { $0.id < $1.id }
        if !pool.isEmpty {
            var used: Set<String> = []
            var attempts = 0
            while questions.count < questionCount, attempts < pool.count * 4 {
                attempts += 1
                let picked = pool[Int(rng.next() % UInt64(pool.count))]
                guard used.insert(picked.id).inserted else { continue }
                questions.append(DailyDrillQuestion(
                    category: category(forCourt: picked.courtID),
                    item: SessionBuilder.prepared(picked)
                ))
            }
        }

        return DailyDrillChallenge(
            day: day,
            dayKey: dayKey,
            shortDate: shortDate(for: day, calendar: calendar),
            questions: questions
        )
    }

    private static func category(forCourt courtID: String) -> DailyDrillCategory {
        switch courtID {
        case DrillLibrary.kitchenCourtID: return .softGame
        case DrillLibrary.transitionCourtID: return .transition
        case DrillLibrary.pressureCourtID: return .pressure
        default: return .softGame
        }
    }

    static func key(for day: Date, calendar: Calendar = dayCalendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: day)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    private static func shortDate(for day: Date, calendar: Calendar = dayCalendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        // The time zone as well as the calendar: without it the formatter falls
        // back to the device zone and can print a different date than `dayKey`
        // was computed from, which is exactly the bug the fixed boundary exists
        // to prevent.
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "MMM d"
        return formatter.string(from: day)
    }

    private static func seed(from dayKey: String) -> UInt64 {
        // FNV-1a. Small, stable, and identical on every device, which is the
        // only property that matters for a shared daily.
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in dayKey.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return hash
    }
}
