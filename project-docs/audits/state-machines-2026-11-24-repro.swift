// State machine audit repro suite, 2026-11-24.
//
// Kept out of the test target on purpose. To run it, copy this file into
// DuprIQTests/ and run:
//   gh-sim test --scheme DuprIQ --only DuprIQTests/StateMachineAuditRepro
// The two claims fail on the starting commit (f17ae53); the two controls pass.
//
// The time zone change is simulated the way it happens on a phone: the
// shared MasteryStore stays resident and reads `Calendar.current`, which
// changes zone under it. Here the state recorded on a New York calendar is
// handed to a store reading a Los Angeles calendar with `load(_:)`, which
// does not roll over, and the launch or foreground rollover is then called
// explicitly with the time it would run at.

import XCTest
@testable import DuprIQ

@MainActor
final class StateMachineAuditRepro: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "dupriq.audit.\(UUID().uuidString)"
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

    // MARK: - SM-B1: a westward time zone change ends the streak

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

    // MARK: - SM-B2: a westward change mid-day restarts today's count

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
}
