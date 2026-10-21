import XCTest
@testable import DuprIQ

/// The contract for points.
///
/// A session is now a run of rallies rather than a pile of unrelated balls, and
/// two things about that can go quietly wrong: a point can contain a shot the
/// player would never hit from where they are, and a session can promise more
/// balls than the free allowance can grade. Both are invisible on screen and
/// both are exactly what this file exists to catch.
final class RallyBuilderTests: XCTestCase {

    private func script(servingTeam: Bool, seed: UInt64) -> [RallyPhase] {
        var rng = SeededGenerator(seed: seed)
        return RallyBuilder.script(servingTeam: servingTeam, rng: &rng)
    }

    /// The one that would train a sequence that cannot happen. You only hit a
    /// third shot if your team served, and you only hit a return if it did not.
    func testAPointNeverContainsAShotYouCouldNotHit() {
        for seed in 0..<200 as Range<UInt64> {
            let serving = script(servingTeam: true, seed: seed)
            XCTAssertFalse(
                serving.contains(.serveReturn),
                "the serving team does not return serve"
            )
            let returning = script(servingTeam: false, seed: seed)
            XCTAssertFalse(
                returning.contains(.thirdShot),
                "the returning team does not hit the third shot"
            )
        }
    }

    func testAPointOpensWithTheRightShot() {
        for seed in 0..<50 as Range<UInt64> {
            XCTAssertEqual(script(servingTeam: true, seed: seed).first, .thirdShot)
            XCTAssertEqual(script(servingTeam: false, seed: seed).first, .serveReturn)
        }
    }

    func testEveryPointHasAtLeastOneShot() {
        for seed in 0..<50 as Range<UInt64> {
            XCTAssertFalse(script(servingTeam: true, seed: seed).isEmpty)
            XCTAssertFalse(script(servingTeam: false, seed: seed).isEmpty)
        }
    }

    /// The free tier's whole promise. A session that says "shot 2 of 4" and
    /// then stops at the allowance is the paywall arriving as a surprise, which
    /// is the thing the lobby check exists to prevent.
    func testASessionNeverPromisesMoreBallsThanTheBudget() {
        for budget in 1...20 {
            for seed in 0..<12 as Range<UInt64> {
                let balls = RallyBuilder.session(ballBudget: budget, seed: seed &* 977)
                XCTAssertEqual(
                    balls.count, budget,
                    "budget \(budget) produced \(balls.count) balls"
                )
            }
        }
    }

    func testAZeroBudgetProducesNothing() {
        XCTAssertTrue(RallyBuilder.session(ballBudget: 0, seed: 1).isEmpty)
        XCTAssertTrue(RallyBuilder.session(ballBudget: -3, seed: 1).isEmpty)
    }

    func testATruncatedPointCannotAwardAFullPoint() {
        let balls = RallyBuilder.session(ballBudget: 5, seed: 99)
        let points = Dictionary(grouping: balls, by: \.pointIndex)

        XCTAssertEqual(points[0]?.count, 4)
        XCTAssertEqual(points[0]?.filter(\.isLastOfPoint).count, 1)
        XCTAssertEqual(points[1]?.count, 1)
        XCTAssertEqual(points[1]?.first?.shotsInPoint, 4)
        XCTAssertFalse(points[1]?.first?.isLastOfPoint ?? true)
    }

    /// Each point's shots are numbered from zero, contiguously, and exactly one
    /// of them is the last. The HUD reads "shot 2 of 4" straight off these, and
    /// the score is awarded on `isLastOfPoint`.
    func testShotNumberingIsContiguousAndHasExactlyOneEnding() {
        let balls = RallyBuilder.session(ballBudget: 40, seed: 99)
        let byPoint = Dictionary(grouping: balls, by: \.pointIndex)
        for (pointIndex, point) in byPoint {
            let sorted = point.sorted { $0.shotIndex < $1.shotIndex }
            XCTAssertEqual(
                sorted.map(\.shotIndex), Array(0..<sorted.count),
                "point \(pointIndex) has gaps in its shot numbering"
            )
            XCTAssertEqual(
                sorted.filter(\.isLastOfPoint).count, 1,
                "point \(pointIndex) does not have exactly one final shot"
            )
            for ball in sorted {
                XCTAssertEqual(ball.shotsInPoint, sorted.count)
            }
        }
    }

    func testPointIndicesAreContiguousFromZero() {
        let balls = RallyBuilder.session(ballBudget: 30, seed: 7)
        let points = Array(Set(balls.map(\.pointIndex))).sorted()
        XCTAssertEqual(points, Array(0..<points.count))
    }

    /// Losing a point skips the rest of it. This is the lookup that does it, so
    /// it has to land on a strictly later point and never inside the current
    /// one.
    func testFirstBallAfterSkipsTheWholeLostPoint() {
        let balls = RallyBuilder.session(ballBudget: 30, seed: 55)
        for ball in balls {
            guard let next = RallyBuilder.firstBall(after: ball.pointIndex, in: balls) else {
                XCTAssertEqual(ball.pointIndex, balls.map(\.pointIndex).max())
                continue
            }
            XCTAssertGreaterThan(balls[next].pointIndex, ball.pointIndex)
            XCTAssertEqual(balls[next].shotIndex, 0, "a rally resumes at its first shot")
        }
    }

    func testFirstBallAfterTheLastPointIsNil() {
        let balls = RallyBuilder.session(ballBudget: 12, seed: 3)
        let last = balls.map(\.pointIndex).max() ?? 0
        XCTAssertNil(RallyBuilder.firstBall(after: last, in: balls))
    }

    /// Every third point is a single focus ball, and when the focus names a
    /// trap the generated position must actually offer that trap.
    func testFocusPointsLandEveryThirdPointAndCarryTheirTrap() {
        let focus = [
            RallyFocus(phase: .dinkRally, mistakeID: "attacked-a-low-ball"),
            RallyFocus(phase: .transition, mistakeID: nil),
        ]
        for seed in UInt64(1)...40 {
            let balls = RallyBuilder.session(ballBudget: 30, seed: seed &* 131, focus: focus)
            let focusBalls = balls.filter { $0.focus != nil }
            XCTAssertFalse(focusBalls.isEmpty)
            for ball in focusBalls {
                XCTAssertEqual(ball.pointIndex % RallyBuilder.focusEvery, RallyBuilder.focusEvery - 1)
                XCTAssertEqual(ball.shotsInPoint, 1)
                XCTAssertEqual(ball.position.phase, ball.focus?.phase)
            }
            for ball in balls where ball.focus == nil {
                XCTAssertNotEqual(ball.pointIndex % RallyBuilder.focusEvery, RallyBuilder.focusEvery - 1)
            }
        }
    }

    func testAFocusQuestionOffersTheNamedTrapWhenThePhaseCanSetIt() {
        var offered = 0
        for seed in UInt64(1)...60 {
            let question = RallyBuilder.focusQuestion(
                RallyFocus(phase: .dinkRally, mistakeID: "attacked-a-low-ball"), seed: seed
            )
            XCTAssertEqual(question.position.phase, .dinkRally)
            if MistakeCatalog.mistakes(for: question).values.contains(where: { $0.id == "attacked-a-low-ball" }) {
                offered += 1
            }
        }
        XCTAssertGreaterThan(offered, 50, "rejection sampling should find the trap almost every time")
    }

    func testNoFocusMeansNoFocusPoints() {
        let balls = RallyBuilder.session(ballBudget: 30, seed: 5)
        XCTAssertTrue(balls.allSatisfy { $0.focus == nil })
    }

    /// The side a player chose is the side they stand on, and mirroring never
    /// changes which shot is right.
    func testThePlayerStandsOnTheHalfTheyChose() {
        for half in [CourtHalf.left, .right] {
            let balls = RallyBuilder.session(
                ballBudget: 30, seed: 77, focus: [RallyFocus(phase: .attack, mistakeID: nil)], half: half
            )
            for ball in balls {
                XCTAssertEqual(ball.position.you.isLeftHalf, half == .left, ball.position.id)
                XCTAssertEqual(ball.question.answer, ShotAdvisor.verdict(for: ball.position).best)
            }
        }
    }

    /// Seedable, because a session you cannot reproduce is a session you cannot
    /// file a bug against, and because the screenshot fixtures pin a seed.
    func testSessionsAreDeterministicForASeed() {
        let a = RallyBuilder.session(ballBudget: 15, seed: 12_345)
        let b = RallyBuilder.session(ballBudget: 15, seed: 12_345)
        XCTAssertEqual(a.map(\.id), b.map(\.id))
        XCTAssertEqual(a.map(\.position.phase), b.map(\.position.phase))
    }

    /// Every ball in a rally is still a real graded question: the options
    /// contain the advisor's answer, which is the contract `DrillQuestion`
    /// enforces at construction and the whole paid loop rests on.
    func testEveryBallInARallyIsAnswerable() {
        let balls = RallyBuilder.session(ballBudget: 40, seed: 808)
        for ball in balls {
            XCTAssertTrue(ball.question.options.contains(ball.question.verdict.best))
            XCTAssertEqual(
                ball.question.options[ball.question.answerIndex],
                ball.question.verdict.best
            )
        }
    }
}
