import XCTest
@testable import DuprIQ

/// When Apple's rating prompt may be called: the good-run moment and the
/// tracker's gates.
@MainActor
final class ReviewPromptTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "dupriq.review.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    // MARK: - The moment

    func testARunKeepingHalfTheBallsOrMoreIsAGoodMoment() {
        XCTAssertTrue(ReviewMoment.isGoodRun(answered: 10, correct: 5, playable: 0, stoppedAtFreeLimit: false))
        XCTAssertTrue(ReviewMoment.isGoodRun(answered: 10, correct: 3, playable: 2, stoppedAtFreeLimit: false),
                      "a playable ball kept the rally too")
        XCTAssertTrue(ReviewMoment.isGoodRun(answered: 12, correct: 12, playable: 0, stoppedAtFreeLimit: false))
        XCTAssertTrue(ReviewMoment.isGoodRun(answered: 4, correct: 2, playable: 0, stoppedAtFreeLimit: false))
    }

    func testABadRunIsNotAMoment() {
        XCTAssertFalse(ReviewMoment.isGoodRun(answered: 10, correct: 4, playable: 0, stoppedAtFreeLimit: false))
        XCTAssertFalse(ReviewMoment.isGoodRun(answered: 9, correct: 2, playable: 2, stoppedAtFreeLimit: false))
        XCTAssertFalse(ReviewMoment.isGoodRun(answered: 6, correct: 0, playable: 0, stoppedAtFreeLimit: false))
    }

    func testARunTooShortToJudgeIsNotAMoment() {
        XCTAssertFalse(ReviewMoment.isGoodRun(answered: 3, correct: 3, playable: 0, stoppedAtFreeLimit: false))
        XCTAssertFalse(ReviewMoment.isGoodRun(answered: 0, correct: 0, playable: 0, stoppedAtFreeLimit: false))
    }

    /// The free-limit summary carries the Pro pitch; the rating stays off it.
    func testARunEndingAtTheFreeLimitIsNotAMoment() {
        XCTAssertFalse(ReviewMoment.isGoodRun(answered: 10, correct: 9, playable: 0, stoppedAtFreeLimit: true))
    }

    // MARK: - The gates

    func testTheFirstLaunchNeverAsksAndTheSecondDoes() {
        let reviews = ReviewPromptTracker(defaults: defaults)
        XCTAssertFalse(reviews.shouldRequestReview(), "no launch recorded")
        reviews.recordAppLaunch()
        XCTAssertEqual(reviews.launchCount, 1)
        XCTAssertFalse(reviews.shouldRequestReview(), "the first session never asks")
        reviews.recordAppLaunch()
        XCTAssertTrue(reviews.shouldRequestReview(), "from the second cold launch on")
    }

    func testThirtyDaysPassBetweenAsks() {
        let reviews = ReviewPromptTracker(defaults: defaults)
        reviews.recordAppLaunch()
        reviews.recordAppLaunch()
        let asked = Date(timeIntervalSince1970: 1_790_000_000)
        reviews.markAsked(now: asked)
        XCTAssertFalse(reviews.shouldRequestReview(now: asked))
        XCTAssertFalse(reviews.shouldRequestReview(now: asked.addingTimeInterval(29 * 86_400)))
        XCTAssertTrue(reviews.shouldRequestReview(now: asked.addingTimeInterval(30 * 86_400)))
        // A stamp the clock ran past is no evidence of an ask.
        XCTAssertTrue(reviews.shouldRequestReview(now: asked.addingTimeInterval(-86_400)))
    }

    func testOpeningTheWriteReviewPageEndsTheAsks() {
        let reviews = ReviewPromptTracker(defaults: defaults)
        reviews.recordAppLaunch()
        reviews.recordAppLaunch()
        let opened = Date(timeIntervalSince1970: 1_790_000_000)
        reviews.markOpenedWriteReview(now: opened)
        XCTAssertFalse(reviews.shouldRequestReview(now: opened.addingTimeInterval(400 * 86_400)))
        XCTAssertFalse(ReviewPromptTracker(defaults: defaults).shouldRequestReview(
            now: opened.addingTimeInterval(400 * 86_400)), "kept across launches")
    }

    func testGatesPersistAcrossLaunches() {
        let first = ReviewPromptTracker(defaults: defaults)
        first.recordAppLaunch()
        let second = ReviewPromptTracker(defaults: defaults)
        second.recordAppLaunch()
        XCTAssertEqual(second.launchCount, 2)
        XCTAssertTrue(second.shouldRequestReview())
    }

    /// An install that finished runs under the old counter is past its first
    /// session: its first launch after the update counts as the second.
    func testAnExistingPlayersFirstLaunchAfterTheUpdateMayAsk() {
        defaults.set(2, forKey: "review.completedSessions")
        defaults.set(true, forKey: "review.hasPrompted")
        let reviews = ReviewPromptTracker(defaults: defaults)
        reviews.recordAppLaunch()
        XCTAssertEqual(reviews.launchCount, 2)
        XCTAssertTrue(reviews.shouldRequestReview())
        reviews.recordAppLaunch()
        XCTAssertEqual(reviews.launchCount, 3, "the seed applies once")
    }

    func testAFreshInstallIsNotSeeded() {
        let reviews = ReviewPromptTracker(defaults: defaults)
        reviews.recordAppLaunch()
        XCTAssertEqual(reviews.launchCount, 1)
    }

    func testTheWriteReviewLinkPointsAtTheListing() {
        XCTAssertEqual(
            AppStoreLinks.writeReviewURL?.absoluteString,
            "https://apps.apple.com/app/id6804828001?action=write-review"
        )
    }
}
