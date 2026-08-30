import XCTest
@testable import DuprIQ

/// The half of the app the content tests cannot see.
///
/// The generator contract is well covered, and that is exactly why these
/// matter: the daily cap, the streak rule, the sample threshold, the practice
/// history and the review gate can all regress without a single generator test
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

    // MARK: - Accuracy signal

    func testAPhaseShowsNoPercentageUntilItHasASample() {
        let progress = ProgressStore(defaults: defaults)
        XCTAssertEqual(progress.signal(for: .dinkRally), .untried)

        progress.record(phase: .dinkRally, wasCorrect: false)
        // One wrong ball is not a 0%.
        XCTAssertEqual(
            progress.signal(for: .dinkRally),
            .building(answered: 1, needed: ProgressThreshold.sampleForAccuracy)
        )

        for _ in 1..<ProgressThreshold.sampleForAccuracy {
            progress.record(phase: .dinkRally, wasCorrect: true)
        }
        guard case .measured(let accuracy) = progress.signal(for: .dinkRally) else {
            return XCTFail("a full sample should read as measured")
        }
        XCTAssertEqual(accuracy, 4.0 / 5.0, accuracy: 0.0001)
    }

    func testWeakestPhaseIsOnlyClaimedOnceItIsMeasured() {
        let progress = ProgressStore(defaults: defaults)
        XCTAssertNil(progress.measuredWeakestPhase)

        // An untouched phase is a suggestion, never a measured weakness.
        let suggestion = progress.recommendation
        XCTAssertNotNil(suggestion)
        XCTAssertFalse(suggestion?.isMeasured ?? true)

        for _ in 0..<ProgressThreshold.sampleForAccuracy {
            progress.record(phase: .transition, wasCorrect: false)
        }
        for _ in 0..<ProgressThreshold.sampleForAccuracy {
            progress.record(phase: .dinkRally, wasCorrect: true)
        }
        XCTAssertEqual(progress.measuredWeakestPhase, .transition)
        XCTAssertEqual(progress.recommendation?.phase, .transition)
        XCTAssertTrue(progress.recommendation?.isMeasured ?? false)
    }

    // MARK: - Streak

    func testOneBallDoesNotStartAStreak() {
        let progress = ProgressStore(defaults: defaults)
        progress.record(phase: .dinkRally, wasCorrect: true)
        XCTAssertEqual(progress.streak, 0, "a single tap is not a practice day")
        XCTAssertEqual(progress.ballsToPracticeDay, ProgressThreshold.ballsForPracticeDay - 1)
    }

    func testAStreakStartsAtTheDailyBallThreshold() {
        let progress = ProgressStore(defaults: defaults)
        for _ in 0..<ProgressThreshold.ballsForPracticeDay {
            progress.record(phase: .dinkRally, wasCorrect: true)
        }
        XCTAssertEqual(progress.streak, 1)
        XCTAssertEqual(progress.ballsToPracticeDay, 0)

        // Extra balls on the same day do not inflate it.
        progress.record(phase: .dinkRally, wasCorrect: true)
        XCTAssertEqual(progress.streak, 1)
    }

    func testConsecutiveDaysExtendTheStreakAndAGapResetsIt() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let progress = ProgressStore(defaults: defaults)

        func practiceDay(_ date: Date) {
            for _ in 0..<ProgressThreshold.ballsForPracticeDay {
                progress.record(phase: .dinkRally, wasCorrect: true, on: date)
            }
        }

        practiceDay(calendar.date(byAdding: .day, value: -2, to: today)!)
        XCTAssertEqual(progress.streak, 1)
        practiceDay(calendar.date(byAdding: .day, value: -1, to: today)!)
        XCTAssertEqual(progress.streak, 2)
        practiceDay(today)
        XCTAssertEqual(progress.streak, 3)

        let afterAGap = calendar.date(byAdding: .day, value: 3, to: today)!
        practiceDay(afterAGap)
        XCTAssertEqual(progress.streak, 1, "a missed day restarts the streak")
    }

    // MARK: - History

    func testSessionsAndMissedPrinciplesArePersisted() {
        let progress = ProgressStore(defaults: defaults)
        progress.record(phase: .transition, wasCorrect: false,
                        principle: "Reset off your shoetops, never drive")
        progress.record(phase: .transition, wasCorrect: false,
                        principle: "Reset off your shoetops, never drive")
        progress.record(phase: .defense, wasCorrect: false,
                        principle: "Reset, don't counter-drive")
        progress.record(phase: .dinkRally, wasCorrect: true,
                        principle: "Cross-court is the longest, safest diagonal")
        progress.recordSession(phase: .transition, answered: 4, correct: 1)

        XCTAssertEqual(progress.recentSessions.count, 1)
        XCTAssertEqual(progress.recentSessions.first?.answered, 4)
        // Ranked by how often it bites, so the top row is the practice plan.
        XCTAssertEqual(progress.topMissedPrinciples.first?.count, 2)
        XCTAssertEqual(progress.topMissedPrinciples.first?.rallyPhase, .transition)
        XCTAssertEqual(progress.topMissedPrinciples.count, 2, "a correct answer must not log a miss")

        // A second store on the same defaults sees the same history.
        let reloaded = ProgressStore(defaults: defaults)
        XCTAssertEqual(reloaded.recentSessions.count, 1)
        XCTAssertEqual(reloaded.topMissedPrinciples.first?.principle,
                       "Reset off your shoetops, never drive")
        XCTAssertEqual(reloaded.totalAnswered, 4)
        XCTAssertEqual(reloaded.totalSessions, 1)
    }

    func testCorrectTargetedItemResolvesOnlyItsAssignedMistake() {
        let store = PracticeRecordStore(defaults: defaults)
        let target = MistakePattern(
            id: "attacked-a-low-ball",
            phase: RallyPhase.dinkRally.rawValue,
            summary: "target"
        )
        let other = MistakePattern(
            id: "unrelated-pattern",
            phase: RallyPhase.transition.rawValue,
            summary: "other"
        )
        store.recordMistake(target)
        store.recordMistake(other)
        let item = EndlessPractice.targetedItems(for: [target], count: 1, seed: 77)[0]

        store.record(item: item, selectedIndex: item.answerIndex)

        XCTAssertNil(store.mistakes[target.id])
        XCTAssertEqual(store.mistakes[other.id]?.outstanding, 1)
    }

    func testSessionTotalIncludesGeneratedAndAuthoredSessions() {
        let progress = ProgressStore(defaults: defaults)

        progress.recordSession(phase: .transition, answered: 4, correct: 3)
        progress.recordSession(drillID: "court-awareness")

        XCTAssertEqual(progress.totalSessions, 2)
        XCTAssertEqual(ProgressStore(defaults: defaults).totalSessions, 2)
    }

    func testProgressRollsOverBeforeTheNextAnswer() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let progress = ProgressStore(defaults: defaults)

        for _ in 0..<ProgressThreshold.ballsForPracticeDay {
            progress.record(phase: .dinkRally, wasCorrect: true, on: today)
        }
        XCTAssertEqual(progress.ballsToday, ProgressThreshold.ballsForPracticeDay)

        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        progress.rollOverIfNeeded(now: tomorrow)

        XCTAssertEqual(progress.ballsToday, 0)
        XCTAssertEqual(progress.ballsToPracticeDay, ProgressThreshold.ballsForPracticeDay)
    }

    func testAnEmptySessionIsNotRecorded() {
        let progress = ProgressStore(defaults: defaults)
        progress.recordSession(phase: nil, answered: 0, correct: 0)
        XCTAssertTrue(progress.recentSessions.isEmpty)
    }

    func testSessionHistoryIsCapped() {
        let progress = ProgressStore(defaults: defaults)
        for _ in 0..<(ProgressStore.maxSessions + 10) {
            progress.recordSession(phase: .attack, answered: 10, correct: 5)
        }
        XCTAssertEqual(progress.recentSessions.count, ProgressStore.maxSessions)
    }

    // MARK: - Review funnel

    func testTheEnjoymentGateWaitsForEnoughSessionsAndOnlyFiresOnce() {
        let reviews = ReviewPromptTracker(defaults: defaults)
        XCTAssertFalse(reviews.shouldShowEnjoymentGate)
        reviews.recordSessionFinished()
        reviews.recordSessionFinished()
        XCTAssertFalse(reviews.shouldShowEnjoymentGate, "two sessions is not an opinion yet")
        reviews.recordSessionFinished()
        XCTAssertTrue(reviews.shouldShowEnjoymentGate)

        reviews.markPrompted()
        XCTAssertFalse(reviews.shouldShowEnjoymentGate)
        reviews.recordSessionFinished()
        XCTAssertFalse(reviews.shouldShowEnjoymentGate, "the one-shot prompt must stay spent")
    }
}
