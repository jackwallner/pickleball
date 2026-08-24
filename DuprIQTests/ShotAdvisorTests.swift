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

    func testThirdShotDropsWhenBothOpponentsAreSetAndTheBallIsLow() {
        let position = makePosition(
            phase: .thirdShot,
            you: CourtPoint(x: 10, y: 3),
            opponentLeft: CourtPoint(x: 6, y: 29.5),
            opponentRight: CourtPoint(x: 14, y: 29.5),
            ballHeight: .belowNet
        )
        let verdict = ShotAdvisor.verdict(for: position)
        XCTAssertEqual(verdict.best, Shot(.drop, .crossCourtKitchen))
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
}
