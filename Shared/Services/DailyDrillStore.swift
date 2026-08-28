import Foundation

struct DailyDrillResult: Codable, Identifiable, Sendable {
    let dayKey: String
    let shortDate: String
    let completedAt: Date
    let answers: [Bool]
    let correctByCategory: [String: Int]
    let totalByCategory: [String: Int]

    var id: String { dayKey }
    var score: Int { answers.filter { $0 }.count }
    var total: Int { answers.count }

    func correct(in category: DailyDrillCategory) -> Int {
        correctByCategory[category.rawValue, default: 0]
    }

    func total(in category: DailyDrillCategory) -> Int {
        totalByCategory[category.rawValue, default: 0]
    }

    var shareText: String {
        let grid = answers.map { $0 ? "🟩" : "⬜️" }.joined()
        let base = "Code Minute \(shortDate): \(score)/\(total)\n\(grid)"
        // `productURL` is nil until the listing is live, so a pre-launch share
        // is the score and the grid, not the score and a 404.
        guard let url = AppStoreLinks.productURL else { return base }
        return base + "\nCan you beat me? \(url.absoluteString)"
    }
}

@MainActor
final class DailyDrillStore: ObservableObject {
    static let shared = DailyDrillStore()

    @Published private(set) var results: [String: DailyDrillResult]

    private let defaults: UserDefaults
    private static let resultsKey = "dailyDrill.results"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.resultsKey),
           let decoded = try? JSONDecoder().decode([String: DailyDrillResult].self, from: data) {
            results = decoded
        } else {
            results = [:]
        }
    }

    func result(for day: Date, calendar: Calendar = DailyDrillContent.dayCalendar) -> DailyDrillResult? {
        results[DailyDrillContent.key(for: day, calendar: calendar)]
    }

    @discardableResult
    func record(
        challenge: DailyDrillChallenge,
        answers: [Bool],
        now: Date = Date()
    ) -> DailyDrillResult {
        if let existing = results[challenge.dayKey] { return existing }

        var correctByCategory: [String: Int] = [:]
        var totalByCategory: [String: Int] = [:]
        for (question, correct) in zip(challenge.questions, answers) {
            totalByCategory[question.category.rawValue, default: 0] += 1
            if correct { correctByCategory[question.category.rawValue, default: 0] += 1 }
        }
        let result = DailyDrillResult(
            dayKey: challenge.dayKey,
            shortDate: challenge.shortDate,
            completedAt: now,
            answers: answers,
            correctByCategory: correctByCategory,
            totalByCategory: totalByCategory
        )
        results[challenge.dayKey] = result
        persist()
        return result
    }

    func completedThisWeek(now: Date = Date(), calendar: Calendar = DailyDrillContent.dayCalendar) -> Int {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: now) else { return 0 }
        return results.values.filter { interval.contains($0.completedAt) }.count
    }

    func archiveDates(
        before day: Date = Date(),
        count: Int = 30,
        calendar: Calendar = DailyDrillContent.dayCalendar
    ) -> [Date] {
        (1...count).compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: day)
        }
    }

    func resetAll() {
        results = [:]
        defaults.removeObject(forKey: Self.resultsKey)
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(results) else { return }
        defaults.set(data, forKey: Self.resultsKey)
    }
}
