import XCTest
@testable import DuprIQ

/// Content validity for a generated app.
///
/// The generator is the product, so the tests that matter are the ones that
/// hold for *every* position it can ever emit, not for a handful of authored
/// examples. Anything that only holds for a fixed question bank is not worth
/// asserting here.
final class ShotAdvisorTests: XCTestCase {

    private let sampleSeeds: [UInt64] = Array(1...400)

    // MARK: - Canonical scenarios

    func testDeepReturnIsAlwaysTheAnswerOnTheReturnOfServe() {
        // The whole phase exists to train out driving the return, so this must
        // hold even when the ball is sitting up invitingly.
        for seed in sampleSeeds {
            let question = PositionGenerator.question(phase: .serveReturn, seed: seed)
            XCTAssertEqual(question.verdict.best.type, .deepReturn,
                           "seed \(seed) returned \(question.verdict.best.label)")
        }
    }

    func testThirdShotDropsCrossCourtFromWideWhenBothOpponentsAreSet() {
        let position = makePosition(
            phase: .thirdShot,
            you: CourtPoint(x: 3, y: 3),
            opponentLeft: CourtPoint(x: 6, y: 29.5),
            opponentRight: CourtPoint(x: 14, y: 29.5),
            ballHeight: .belowNet
        )
        let verdict = ShotAdvisor.verdict(for: position)
        XCTAssertEqual(verdict.best, Shot(.drop, .crossCourtKitchen))
        // Hitting from the left side, the long diagonal is the right opponent.
        XCTAssertEqual(verdict.targetOpponent, .right)
    }

    func testThirdShotDropsStraightFromTheMiddleWhereNoDiagonalExists() {
        // Lateral position is load-bearing, not decoration: from the middle of
        // the court the cross-court ball is barely longer than the straight one,
        // so the answer changes.
        let position = makePosition(
            phase: .thirdShot,
            you: CourtPoint(x: 10, y: 3),
            opponentLeft: CourtPoint(x: 6, y: 29.5),
            opponentRight: CourtPoint(x: 14, y: 29.5),
            ballHeight: .belowNet
        )
        XCTAssertEqual(ShotAdvisor.verdict(for: position).best, Shot(.drop, .straightKitchen))
    }

    func testThirdShotDrivesAtTheOpponentWhoIsNotSet() {
        let position = makePosition(
            phase: .thirdShot,
            you: CourtPoint(x: 10, y: 3),
            opponentLeft: CourtPoint(x: 6, y: 29.5),      // at the line
            opponentRight: CourtPoint(x: 14, y: 36),      // still coming in
            ballHeight: .belowNet
        )
        let verdict = ShotAdvisor.verdict(for: position)
        XCTAssertEqual(verdict.best, Shot(.drive, .atFeet))
        XCTAssertEqual(verdict.targetOpponent, .right, "the answer must name the player it means")
    }

    func testTransitionNeverDrivesALowBall() {
        for seed in sampleSeeds {
            let question = PositionGenerator.question(phase: .transition, seed: seed)
            guard question.position.ballHeight != .aboveNet else { continue }
            XCTAssertEqual(question.verdict.best.type, .reset,
                           "seed \(seed) chose \(question.verdict.best.label) off a low ball")
        }
    }

    func testDinkRallyNeverSpeedsUpFromBelowTheNet() {
        for seed in sampleSeeds {
            let question = PositionGenerator.question(phase: .dinkRally, seed: seed)
            guard question.position.ballHeight == .belowNet else { continue }
            XCTAssertNotEqual(question.verdict.best.type, .speedUp,
                              "seed \(seed) attacked a ball below the net")
            XCTAssertNotEqual(question.verdict.best.type, .putAway)
        }
    }

    func testAttackPhaseAlwaysHitsDownward() {
        for seed in sampleSeeds {
            let question = PositionGenerator.question(phase: .attack, seed: seed)
            XCTAssertTrue([.putAway, .drive].contains(question.verdict.best.type),
                          "seed \(seed) declined a ball above the net")
        }
    }

    // MARK: - Totality

    func testEveryPhaseAndSeedProducesAVerdictWithAPrinciple() {
        for phase in RallyPhase.allCases {
            for seed in sampleSeeds {
                let verdict = PositionGenerator.question(phase: phase, seed: seed).verdict
                XCTAssertFalse(verdict.principle.isEmpty)
                XCTAssertFalse(verdict.why.isEmpty)
            }
        }
    }

    func testVerdictIsDeterministicForAGivenSeed() {
        for phase in RallyPhase.allCases {
            let first = PositionGenerator.question(phase: phase, seed: 12_345)
            let second = PositionGenerator.question(phase: phase, seed: 12_345)
            XCTAssertEqual(first.position, second.position)
            XCTAssertEqual(first.verdict, second.verdict)
            XCTAssertEqual(first.options, second.options)
        }
    }

    // MARK: - Helpers

    private func makePosition(
        phase: RallyPhase,
        you: CourtPoint,
        opponentLeft: CourtPoint,
        opponentRight: CourtPoint,
        ballHeight: BallHeight
    ) -> RallyPosition {
        RallyPosition(
            id: "test", phase: phase,
            you: you,
            partner: CourtPoint(x: 10, y: 3),
            opponentLeft: opponentLeft,
            opponentRight: opponentRight,
            contact: you,
            ballHeight: ballHeight,
            yourScore: 4, theirScore: 6, isServingTeam: true
        )
    }

    // MARK: - Lateral geometry

    func testAnOpenMiddleChangesTheAnswerInADinkRally() {
        // Same phase, same ball height, same zones: only the seam between the
        // two opponents moves. If the answer does not move with it, the exact
        // feet on the diagram are decoration.
        let tight = makePosition(
            phase: .dinkRally,
            you: CourtPoint(x: 4, y: 14.2),
            opponentLeft: CourtPoint(x: 9, y: 29.5),
            opponentRight: CourtPoint(x: 12, y: 29.5),
            ballHeight: .belowNet
        )
        let wide = makePosition(
            phase: .dinkRally,
            you: CourtPoint(x: 4, y: 14.2),
            opponentLeft: CourtPoint(x: 3.5, y: 29.5),
            opponentRight: CourtPoint(x: 16.5, y: 29.5),
            ballHeight: .belowNet
        )
        XCTAssertEqual(ShotAdvisor.verdict(for: tight).best, Shot(.dink, .crossCourtKitchen))
        XCTAssertEqual(ShotAdvisor.verdict(for: wide).best, Shot(.dink, .middle))
    }

    func testAnOpenMiddleChangesTheAnswerOnAnAttack() {
        let tight = makePosition(
            phase: .attack,
            you: CourtPoint(x: 4, y: 14.2),
            opponentLeft: CourtPoint(x: 9, y: 29.5),
            opponentRight: CourtPoint(x: 12, y: 29.5),
            ballHeight: .aboveNet
        )
        let wide = makePosition(
            phase: .attack,
            you: CourtPoint(x: 4, y: 14.2),
            opponentLeft: CourtPoint(x: 3.5, y: 29.5),
            opponentRight: CourtPoint(x: 16.5, y: 29.5),
            ballHeight: .aboveNet
        )
        XCTAssertEqual(ShotAdvisor.verdict(for: tight).best, Shot(.putAway, .atFeet))
        XCTAssertEqual(ShotAdvisor.verdict(for: wide).best, Shot(.putAway, .middle))
    }

    func testTheAnswerIsUnchangedUnderALeftRightMirror() {
        // The single property that proves the drill trains a decision rather
        // than a side: reflect the whole court and the shot must be identical,
        // aimed at the marker that is now in the mirrored place.
        for phase in RallyPhase.allCases {
            for seed in sampleSeeds {
                let position = PositionGenerator.question(phase: phase, seed: seed).position
                // A contact exactly on the center line is its own mirror, so
                // no side choice can be antisymmetric there.
                guard position.contact.x != CourtGeometry.centerX else { continue }
                let original = ShotAdvisor.verdict(for: position)
                let mirrored = ShotAdvisor.verdict(for: position.mirrored)
                XCTAssertEqual(original.best, mirrored.best,
                               "\(phase)/\(seed) changed shot under a mirror")
                XCTAssertEqual(original.principle, mirrored.principle,
                               "\(phase)/\(seed) changed principle under a mirror")
                XCTAssertEqual(original.targetOpponent?.opposite, mirrored.targetOpponent,
                               "\(phase)/\(seed) did not follow the target across the mirror")
            }
        }
    }

    func testAnAnswerThatNamesAnOpponentAlwaysCarriesTheSide() {
        // "Hit the player who isn't set" is only coaching if the app can point
        // at that player. Every lagging-opponent verdict must carry the side.
        for phase in RallyPhase.allCases {
            for seed in sampleSeeds {
                let question = PositionGenerator.question(phase: phase, seed: seed)
                guard let lagging = question.position.laggingOpponentSide else { continue }
                XCTAssertEqual(question.verdict.targetOpponent, lagging,
                               "\(phase)/\(seed) grades a lagging opponent without naming them")
            }
        }
    }

    func testAnyNamedTargetIsAnOpponentThatActuallyExists() {
        for phase in RallyPhase.allCases {
            for seed in sampleSeeds {
                let question = PositionGenerator.question(phase: phase, seed: seed)
                guard let target = question.verdict.targetOpponent else { continue }
                let point = question.position.opponent(target)
                XCTAssertGreaterThan(point.y, CourtGeometry.netY,
                                     "\(phase)/\(seed) targets a marker on our own side")
            }
        }
    }
}
