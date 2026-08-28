import XCTest
@testable import DuprIQ

/// The contract for aiming.
///
/// The app stopped asking players to pick a sentence and started asking them to
/// pick a place, which means `ShotTarget` acquired geometry it never had. If a
/// landing point lands on our own side of the net, outside the paint, or on top
/// of another option, the question is not answerable and the paid loop is
/// broken in a way no generator test would catch.
final class ShotTargetingTests: XCTestCase {

    private func everyGeneratedQuestion(
        count: Int = 60, _ body: (DrillQuestion) -> Void
    ) {
        for phase in RallyPhase.allCases {
            for seed in 0..<UInt64(count) {
                body(PositionGenerator.question(phase: phase, seed: seed &* 7919 &+ 13))
            }
        }
    }

    func testEveryAimPointIsOnTheirSideAndInsideTheCourt() {
        everyGeneratedQuestion { question in
            let points = ShotAiming.aimPoints(
                for: question.options, in: question.position,
                answer: question.answer,
                answerTarget: question.verdict.targetOpponent
            )
            for (shot, point) in zip(question.options, points) {
                XCTAssertGreaterThan(
                    point.y, CourtGeometry.netY,
                    "\(question.position.id): \(shot.id) lands on our own side"
                )
                XCTAssertLessThanOrEqual(point.y, CourtGeometry.length)
                XCTAssertGreaterThanOrEqual(point.x, 0)
                XCTAssertLessThanOrEqual(point.x, CourtGeometry.width)
            }
        }
    }

    /// The one that actually breaks the screen. Two options that resolve to the
    /// same square foot draw one ring on top of another, and whichever loses is
    /// an option the player cannot pick. The attack phase really does offer
    /// "Put it away, at their feet" and "Drive, at their feet", so this is not
    /// hypothetical.
    func testNoTwoOptionsShareAnAimPoint() {
        everyGeneratedQuestion { question in
            let points = ShotAiming.aimPoints(
                for: question.options, in: question.position,
                answer: question.answer,
                answerTarget: question.verdict.targetOpponent
            )
            for i in points.indices {
                for j in points.indices where j > i {
                    let dx = points[i].x - points[j].x
                    let dy = points[i].y - points[j].y
                    let distance = (dx * dx + dy * dy).squareRoot()
                    XCTAssertGreaterThan(
                        distance, 1.2,
                        "\(question.position.id): \(question.options[i].id) and "
                        + "\(question.options[j].id) land on top of each other"
                    )
                }
            }
        }
    }

    func testAimPointCountMatchesOptionCount() {
        everyGeneratedQuestion(count: 20) { question in
            let points = ShotAiming.aimPoints(for: question.options, in: question.position)
            XCTAssertEqual(points.count, question.options.count)
        }
    }

    /// Where a ball at someone's feet goes is not a guess: it goes at the feet
    /// of the player the verdict named.
    func testAtFeetLandsInFrontOfTheNamedOpponent() {
        for seed in 0..<80 as Range<UInt64> {
            let question = PositionGenerator.question(phase: .attack, seed: seed &* 104_729 &+ 7)
            guard let side = question.verdict.targetOpponent else { continue }
            let shot = Shot(.putAway, .atFeet)
            let point = shot.landingPoint(in: question.position, preferring: side)
            let opponent = question.position.opponent(side)
            XCTAssertEqual(point.x, opponent.x, accuracy: 0.01)
            XCTAssertLessThan(point.y, opponent.y, "the ball should land short of their shoes")
        }
    }

    /// Reflecting the court reflects where the ball goes.
    ///
    /// This is the aiming half of `testTheAnswerIsUnchangedUnderALeftRightMirror`:
    /// the advisor already promises the same SHOT on a mirrored court, and this
    /// promises that shot is drawn in the mirrored PLACE, so the drill trains a
    /// decision rather than a side of the screen.
    ///
    /// `.backhand` is deliberately excluded and that is not an oversight. A
    /// right-handed opponent's backhand stays on their left hand whichever end
    /// of the court they are standing on, so a backhand target is the one thing
    /// here that must NOT mirror. `testTheBackhandTargetDoesNotMirror` pins the
    /// opposite property for it.
    func testAimPointsMirrorWithTheCourt() {
        let mirrorable: [ShotTarget] = [
            .crossCourtKitchen, .straightKitchen, .middle,
            .deepCrossCourt, .deepStraight, .atFeet,
        ]
        for phase in RallyPhase.allCases {
            for seed in 0..<25 as Range<UInt64> {
                let position = PositionGenerator.question(
                    phase: phase, seed: seed &* 31 &+ 5
                ).position
                let mirrored = position.mirrored
                for target in mirrorable {
                    let shot = Shot(.drop, target)
                    let a = shot.landingPoint(in: position)
                    let b = shot.landingPoint(in: mirrored)
                    XCTAssertEqual(
                        b.x, CourtGeometry.mirroredX(a.x), accuracy: 0.02,
                        "\(target.rawValue) did not mirror in \(position.id)"
                    )
                    XCTAssertEqual(b.y, a.y, accuracy: 0.02)
                }
            }
        }
    }

    func testTheBackhandTargetDoesNotMirror() {
        // Handedness is a property of the player, not of the court. Aiming at a
        // right-hander's backhand means the same physical shoulder before and
        // after a reflection, so this target is asymmetric on purpose.
        let position = PositionGenerator.question(phase: .dinkRally, seed: 4242).position
        let shot = Shot(.dink, .backhand)
        let straight = shot.landingPoint(in: position, preferring: .left)
        let opponent = position.opponent(.left)
        XCTAssertGreaterThan(
            straight.x, opponent.x,
            "a right-hander's backhand sits on our right of them"
        )
    }
}
