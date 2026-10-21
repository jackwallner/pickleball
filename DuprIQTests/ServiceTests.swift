import XCTest
@testable import DuprIQ

/// The half of the app the content tests cannot see.
///
/// The generator contract is well covered, and that is exactly why these
/// matter: the daily cap, the streak rule, the sample threshold, the practice
/// history and the review prompt can all regress without a single generator test
/// noticing.
@MainActor
final class ServiceTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "duprq.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    // MARK: - Free daily cap

    func testFreeTierStopsAtTheDailyCapAndProNeverDoes() {
        let limiter = PracticeLimiter(defaults: defaults)
        for _ in 0..<PracticeLimiter.freeDailyBalls {
            XCTAssertTrue(limiter.canPractice(isPro: false))
            limiter.consume(isPro: false)
        }
        XCTAssertFalse(limiter.canPractice(isPro: false))
        XCTAssertEqual(limiter.remaining(isPro: false), 0)
        XCTAssertTrue(limiter.canPractice(isPro: true))

        limiter.consume(isPro: true)
        XCTAssertEqual(limiter.remaining(isPro: false), 0, "a Pro ball must not spend a free ball")
    }

    func testTheCapRollsOverOnANewCalendarDay() {
        let limiter = PracticeLimiter(defaults: defaults)
        limiter.consume(isPro: false)
        limiter.consume(isPro: false)
        XCTAssertEqual(limiter.remaining(isPro: false), PracticeLimiter.freeDailyBalls - 2)

        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: .now)!
        limiter.rollOverIfNeeded(now: tomorrow)
        XCTAssertEqual(limiter.remaining(isPro: false), PracticeLimiter.freeDailyBalls)
    }

    func testRollingOverWithinTheSameDayKeepsTheCount() {
        let limiter = PracticeLimiter(defaults: defaults)
        limiter.consume(isPro: false)
        limiter.rollOverIfNeeded(now: .now)
        XCTAssertEqual(limiter.remaining(isPro: false), PracticeLimiter.freeDailyBalls - 1)
    }

    // MARK: - Mastery

    private func question(_ phase: RallyPhase, seed: UInt64) -> DrillQuestion {
        PositionGenerator.question(phase: phase, seed: seed)
    }

    private func wrongIndex(_ q: DrillQuestion) -> Int {
        (q.answerIndex + 1) % q.options.count
    }

    func testAPrincipleShowsNoPercentageUntilItHasASample() {
        let store = MasteryStore(defaults: defaults)
        let q = question(.serveReturn, seed: 3)
        let family = try! XCTUnwrap(Principle.family(forVerdict: q.verdict.principle))
        XCTAssertEqual(store.signal(for: family), .new)

        for _ in 0..<(MasteryThreshold.sample - 1) { store.record(q, picked: q.answerIndex) }
        XCTAssertEqual(store.signal(for: family), .building(answered: MasteryThreshold.sample - 1))

        store.record(q, picked: wrongIndex(q))
        XCTAssertEqual(store.signal(for: family), .measured(0.8))
    }

    func testAMissNamesItsTrapAndAFocusFixClosesIt() {
        let store = MasteryStore(defaults: defaults)
        var found: (DrillQuestion, Int, String)?
        for seed in UInt64(1)...200 {
            let q = question(.dinkRally, seed: seed)
            for (index, shot) in q.options.enumerated() where index != q.answerIndex {
                if let pattern = MistakeCatalog.pattern(for: shot, in: q) {
                    found = (q, index, pattern.id)
                    break
                }
            }
            if found != nil { break }
        }
        let (q, wrong, id) = try! XCTUnwrap(found)

        store.record(q, picked: wrong)
        XCTAssertEqual(store.openMistakes.map(\.id), [id])
        XCTAssertEqual(store.focus(for: .rec).first?.mistakeID, id)

        store.record(q, picked: q.answerIndex, focus: id)
        XCTAssertTrue(store.openMistakes.isEmpty, "one right focus ball after one miss fixes it")
        XCTAssertEqual(store.rankedMistakes.first?.misses, 1, "Pro's ranking keeps the history")

        store.record(q, picked: wrong)
        XCTAssertEqual(store.openMistakes.first?.misses, 2, "a fresh miss reopens the trap")
    }

    func testWithNothingMeasuredFocusComesFromTheLevel() {
        let store = MasteryStore(defaults: defaults)
        XCTAssertEqual(store.focus(for: .new).map(\.phase), ExperienceLevel.new.starterPhases)
        XCTAssertEqual(store.focus(for: .competitive).map(\.phase), ExperienceLevel.competitive.starterPhases)
    }

    func testOneBallDoesNotStartAStreak() {
        let store = MasteryStore(defaults: defaults)
        store.record(question(.attack, seed: 1), picked: 0)
        XCTAssertEqual(store.streak, 0)
    }

    func testConsecutiveDaysExtendTheStreakAndAGapEndsIt() {
        let store = MasteryStore(defaults: defaults)
        let calendar = Calendar.current
        let day0 = calendar.startOfDay(for: .now).addingTimeInterval(-10 * 86_400 + 3_600)
        let q = question(.attack, seed: 1)
        func playDay(_ offset: Int) {
            let date = calendar.date(byAdding: .day, value: offset, to: day0)!
            for _ in 0..<MasteryThreshold.ballsForPracticeDay { store.record(q, picked: 0, on: date) }
        }
        playDay(0)
        XCTAssertEqual(store.streak, 1)
        playDay(1)
        XCTAssertEqual(store.streak, 2)
        playDay(3)
        XCTAssertEqual(store.streak, 1, "a skipped day restarts the streak")

        store.rollOverIfNeeded(now: calendar.date(byAdding: .day, value: 6, to: day0)!)
        XCTAssertEqual(store.streak, 0, "a streak that lapsed reads as zero before the next ball")
    }

    func testRalliesArePersistedAndCapped() {
        let store = MasteryStore(defaults: defaults)
        store.recordRally(won: 0, lost: 0, answered: 0, correct: 0)
        XCTAssertTrue(store.rallies.isEmpty, "an empty run is not history")
        for _ in 0..<(MasteryStore.maxRallies + 5) {
            store.recordRally(won: 3, lost: 2, answered: 12, correct: 9)
        }
        XCTAssertEqual(store.rallies.count, MasteryStore.maxRallies)

        let reloaded = MasteryStore(defaults: defaults)
        XCTAssertEqual(reloaded.rallies.count, MasteryStore.maxRallies)
    }

    // MARK: - Playing settings

    func testTheCourtStartsWithoutADecisionTimer() {
        XCTAssertEqual(AppSettings(defaults: defaults).shotClock, .off)
    }

    func testOnboardingAnswersPersist() {
        let profile = PlayerProfile(defaults: defaults)
        XCTAssertFalse(profile.setupComplete)
        profile.level = .competitive
        profile.half = .left
        profile.markSetupComplete()

        let reloaded = PlayerProfile(defaults: defaults)
        XCTAssertEqual(reloaded.level, .competitive)
        XCTAssertEqual(reloaded.half, .left)
        XCTAssertTrue(reloaded.setupComplete)
    }

    // MARK: - Review funnel

    func testTheReviewPromptWaitsForEnoughSessionsAndOnlyFiresOnce() {
        let reviews = ReviewPromptTracker(defaults: defaults)
        XCTAssertFalse(reviews.shouldRequestReview)
        reviews.recordSessionFinished()
        reviews.recordSessionFinished()
        XCTAssertFalse(reviews.shouldRequestReview, "two sessions is not an opinion yet")
        reviews.recordSessionFinished()
        XCTAssertTrue(reviews.shouldRequestReview)

        reviews.markPrompted()
        XCTAssertFalse(reviews.shouldRequestReview)
        reviews.recordSessionFinished()
        XCTAssertFalse(reviews.shouldRequestReview, "the one-shot prompt must stay spent")
    }
}
