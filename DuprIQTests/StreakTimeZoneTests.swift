import XCTest
@testable import DuprIQ

/// The streak and today's ball count across a time zone change (state machine
/// audit 2026-11-24, B1 and B2), and the upgrade from blobs that stored only
/// start-of-day instants.
@MainActor
final class StreakTimeZoneTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "dupriq.streaktz.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    private func calendar(_ id: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: id)!
        return calendar
    }

    private func at(_ day: Int, _ hour: Int, in calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: day, hour: hour))!
    }

    private func play(_ count: Int, on store: MasteryStore, at date: Date) {
        let q = PositionGenerator.question(phase: .attack, seed: 1)
        for _ in 0..<count { store.record(q, picked: q.answerIndex, on: date) }
    }

    // MARK: - A westward change keeps the streak (audit B1)

    /// A practice day in New York, the next day's in Los Angeles: two
    /// consecutive dates on the player's own clock, so a 2-day streak.
    func testAStreakSurvivesAWestwardTimeZoneChange() {
        let newYork = calendar("America/New_York")
        let losAngeles = calendar("America/Los_Angeles")
        let home = MasteryStore(defaults: defaults, calendar: newYork)
        play(5, on: home, at: at(10, 18, in: newYork))
        XCTAssertEqual(home.streak, 1, "precondition: 10 September counted in New York")

        let away = MasteryStore(defaults: defaults, calendar: losAngeles)
        away.load(home.state)
        XCTAssertEqual(away.streak, 1, "precondition: the same state, read after the flight")

        away.rollOverIfNeeded(now: at(11, 8, in: losAngeles))
        XCTAssertEqual(away.streak, 1, "11 September is the day after the last practice day; the streak is not over")

        play(5, on: away, at: at(11, 12, in: losAngeles))
        XCTAssertEqual(away.streak, 2, "10 and 11 September are consecutive practice days")
    }

    func testControlAStreakAcrossTwoDaysInOneZone() {
        let newYork = calendar("America/New_York")
        let store = MasteryStore(defaults: defaults, calendar: newYork)
        play(5, on: store, at: at(10, 18, in: newYork))
        store.rollOverIfNeeded(now: at(11, 8, in: newYork))
        XCTAssertEqual(store.streak, 1)
        play(5, on: store, at: at(11, 12, in: newYork))
        XCTAssertEqual(store.streak, 2)
    }

    // MARK: - A westward change keeps today's count (audit B2)

    /// Three balls in New York and two more in Los Angeles, all on 10
    /// September on the player's clock: five balls, a practice day.
    func testTodaysBallsSurviveAWestwardTimeZoneChange() {
        let newYork = calendar("America/New_York")
        let losAngeles = calendar("America/Los_Angeles")
        let home = MasteryStore(defaults: defaults, calendar: newYork)
        play(3, on: home, at: at(10, 9, in: newYork))
        XCTAssertEqual(home.ballsToday, 3, "precondition: three balls on 10 September")
        XCTAssertEqual(home.streak, 0, "precondition: not a practice day yet")

        let away = MasteryStore(defaults: defaults, calendar: losAngeles)
        away.load(home.state)
        // 20:00 in Los Angeles is 23:00 in New York: still 10 September in both.
        play(2, on: away, at: at(10, 20, in: losAngeles))
        XCTAssertEqual(away.ballsToday, 5, "all five balls were played on 10 September")
        XCTAssertEqual(away.streak, 1, "five balls on one date make it a practice day")
    }

    func testControlTodaysBallsInOneZone() {
        let newYork = calendar("America/New_York")
        let store = MasteryStore(defaults: defaults, calendar: newYork)
        play(3, on: store, at: at(10, 9, in: newYork))
        play(2, on: store, at: at(10, 23, in: newYork))
        XCTAssertEqual(store.ballsToday, 5)
        XCTAssertEqual(store.streak, 1)
    }

    // MARK: - Upgrade

    /// A blob saved before `lastPracticeDate` and `ballsDate` existed: only
    /// the start-of-day instants. It must decode, keep its streak and count,
    /// and carry on as earlier builds did in the same zone.
    func testABlobSavedBeforeTheDateFieldsKeepsItsStreak() throws {
        let newYork = calendar("America/New_York")
        let now = Date.now
        let today = newYork.startOfDay(for: now)
        let yesterday = newYork.date(byAdding: .day, value: -1, to: today)!
        var legacy = MasteryState()
        legacy.totalAnswered = 40
        legacy.streak = 4
        legacy.lastPracticeDay = yesterday
        legacy.ballsToday = 2
        legacy.ballsDay = today
        let data = try JSONEncoder().encode(legacy)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertNil(json["lastPracticeDate"], "precondition: the blob has no date fields")
        XCTAssertNil(json["ballsDate"], "precondition: the blob has no date fields")
        defaults.set(data, forKey: "mastery.v1")

        let store = MasteryStore(defaults: defaults, calendar: newYork)
        XCTAssertEqual(store.totalAnswered, 40)
        XCTAssertEqual(store.streak, 4, "yesterday was a practice day")
        XCTAssertEqual(store.ballsToday, 2)

        play(3, on: store, at: now)
        XCTAssertEqual(store.ballsToday, 5)
        XCTAssertEqual(store.streak, 5, "today is the next practice day")
        XCTAssertEqual(store.state.lastPracticeDate, CalendarDay(now, in: newYork))

        let reloaded = MasteryStore(defaults: defaults, calendar: newYork)
        XCTAssertEqual(reloaded.streak, 5)
        XCTAssertEqual(reloaded.ballsToday, 5)
    }

    func testCalendarDayCountsDatesNotHours() {
        let santiago = calendar("America/Santiago")
        let first = CalendarDay(at(5, 12, in: santiago), in: santiago)
        let next = CalendarDay(at(6, 12, in: santiago), in: santiago)
        XCTAssertEqual(first.days(until: next), 1)
        XCTAssertEqual(next.days(until: first), -1)
        XCTAssertEqual(first.days(until: first), 0)
    }
}
