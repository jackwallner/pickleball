import XCTest
@testable import DuprIQ

/// The generator's contract. If any of these fail, the paid tier is shipping
/// positions a player can legitimately call broken.
final class PositionGeneratorTests: XCTestCase {

    private let sampleSeeds: [UInt64] = Array(1...300)

    func testEveryGeneratedPositionIsPhysicallyLegal() {
        for phase in RallyPhase.allCases {
            for seed in sampleSeeds {
                let p = PositionGenerator.question(phase: phase, seed: seed).position
                for (name, point) in [("you", p.you), ("partner", p.partner),
                                      ("left", p.opponentLeft), ("right", p.opponentRight),
                                      ("ball", p.contact)] {
                    XCTAssertTrue((0...Court.width).contains(point.x),
                                  "\(phase)/\(seed): \(name) x=\(point.x) off court")
                    XCTAssertTrue((0...Court.length).contains(point.y),
                                  "\(phase)/\(seed): \(name) y=\(point.y) off court")
                }
                XCTAssertLessThan(p.you.y, Court.netY, "\(phase)/\(seed): you crossed the net")
                XCTAssertLessThan(p.partner.y, Court.netY, "\(phase)/\(seed): partner crossed the net")
                XCTAssertGreaterThan(p.opponentLeft.y, Court.netY, "\(phase)/\(seed): opponent on our side")
                XCTAssertGreaterThan(p.opponentRight.y, Court.netY, "\(phase)/\(seed): opponent on our side")
            }
        }
    }

    func testOptionsAlwaysContainTheAnswerExactlyOnce() {
        for phase in RallyPhase.allCases {
            for seed in sampleSeeds {
                let q = PositionGenerator.question(phase: phase, seed: seed)
                let matches = q.options.filter { $0 == q.verdict.best }.count
                XCTAssertEqual(matches, 1,
                               "\(phase)/\(seed): answer appeared \(matches) times")
                XCTAssertEqual(q.options[q.answerIndex], q.verdict.best)
            }
        }
    }

    func testOptionsAreDistinctAndAlwaysFour() {
        for phase in RallyPhase.allCases {
            for seed in sampleSeeds {
                let options = PositionGenerator.question(phase: phase, seed: seed).options
                XCTAssertEqual(options.count, 4, "\(phase)/\(seed)")
                XCTAssertEqual(Set(options).count, options.count,
                               "\(phase)/\(seed): duplicate option shown")
            }
        }
    }

    func testPhaseInvariantsHold() {
        for seed in sampleSeeds {
            // A dink rally is by definition never an attackable ball.
            let dink = PositionGenerator.question(phase: .dinkRally, seed: seed).position
            XCTAssertNotEqual(dink.ballHeight, .aboveNet, "seed \(seed)")
            XCTAssertEqual(dink.yourZone, .kitchen, "seed \(seed)")

            // The attack phase is the opposite: always a ball above the net.
            let attack = PositionGenerator.question(phase: .attack, seed: seed).position
            XCTAssertEqual(attack.ballHeight, .aboveNet, "seed \(seed)")

            // Transition means you are actually in the transition zone.
            let transition = PositionGenerator.question(phase: .transition, seed: seed).position
            XCTAssertEqual(transition.yourZone, .transition, "seed \(seed)")
        }
    }

    func testMixedSessionCoversMoreThanOnePhase() {
        let phases = Set(PositionGenerator.session(count: 40, seed: 99).map(\.position.phase))
        XCTAssertGreaterThan(phases.count, 1)
    }

    func testGeneratorDoesNotRepeatItselfAcrossSeeds() {
        // The paid promise is "never runs out", so distinct seeds must give
        // distinct positions rather than cycling a small hidden bank.
        let ids = Set(sampleSeeds.map {
            PositionGenerator.question(phase: .thirdShot, seed: $0).position.id
        })
        XCTAssertEqual(ids.count, sampleSeeds.count)
    }

    // MARK: - Geometry contract

    func testTheKitchenBucketMatchesTheGeneratedStance() {
        // One physical contract, shared by generation, classification and the
        // diagram. A marker generated as "at the line" must classify as
        // `.kitchen`, and a marker a stride further back must not, or the
        // coaching language and the drawn line disagree.
        for side in [CourtSide.near, CourtSide.far] {
            let atLine = side == .near
                ? Court.netY - Court.kitchenReadyDepth + 0.2
                : Court.netY + Court.kitchenReadyDepth - 0.2
            let stepBack = side == .near
                ? Court.netY - Court.kitchenReadyDepth - 0.2
                : Court.netY + Court.kitchenReadyDepth + 0.2
            XCTAssertEqual(Court.zone(forY: atLine, side: side), .kitchen, "\(side)")
            XCTAssertEqual(Court.zone(forY: stepBack, side: side), .transition, "\(side)")
        }
        // The two sides are reflections of each other, not offset copies.
        for depth in stride(from: 0.5, through: 21.0, by: 0.5) {
            XCTAssertEqual(
                Court.zone(forY: Court.netY - depth, side: .near),
                Court.zone(forY: Court.netY + depth, side: .far),
                "depth \(depth) classifies differently on the two sides"
            )
        }
    }

    func testEveryGeneratedKitchenPlayerClassifiesAsAtTheKitchen() {
        for seed in sampleSeeds {
            let dink = PositionGenerator.question(phase: .dinkRally, seed: seed).position
            XCTAssertEqual(dink.yourZone, .kitchen, "seed \(seed)")
            XCTAssertEqual(dink.partnerZone, .kitchen, "seed \(seed)")
        }
    }

    // MARK: - Left/right balance

    func testLaggingOpponentIsNotAlwaysTheSameSide() {
        // A drill that always leaves the right-hand player short teaches
        // players to look right, not to read feet.
        for phase in [RallyPhase.thirdShot, .dinkRally, .attack] {
            var left = 0
            var right = 0
            for seed in sampleSeeds {
                switch PositionGenerator.question(phase: phase, seed: seed).position.laggingOpponentSide {
                case .left: left += 1
                case .right: right += 1
                case nil: break
                }
            }
            let total = left + right
            XCTAssertGreaterThan(total, 20, "\(phase): almost no lagging scenarios generated")
            XCTAssertGreaterThan(Double(left) / Double(total), 0.3, "\(phase): lagging opponent is \(left) left / \(right) right")
            XCTAssertGreaterThan(Double(right) / Double(total), 0.3, "\(phase): lagging opponent is \(left) left / \(right) right")
        }
    }

    func testContactIsNotAlwaysOnTheSameHalfOfTheCourt() {
        var leftHalf = 0
        for seed in sampleSeeds {
            for phase in RallyPhase.allCases {
                if PositionGenerator.question(phase: phase, seed: seed).position.contact.isLeftHalf {
                    leftHalf += 1
                }
            }
        }
        let total = sampleSeeds.count * RallyPhase.allCases.count
        let share = Double(leftHalf) / Double(total)
        XCTAssertGreaterThan(share, 0.35, "contact lands on the left half \(share)")
        XCTAssertLessThan(share, 0.65, "contact lands on the left half \(share)")
    }

    func testMirroringKeepsAPositionLegal() {
        for phase in RallyPhase.allCases {
            for seed in sampleSeeds.prefix(60) {
                let p = PositionGenerator.question(phase: phase, seed: seed).position.mirrored
                for (name, point) in [("you", p.you), ("partner", p.partner),
                                      ("left", p.opponentLeft), ("right", p.opponentRight),
                                      ("ball", p.contact)] {
                    XCTAssertTrue((0...Court.width).contains(point.x), "\(phase)/\(seed): \(name)")
                    XCTAssertTrue((0...Court.length).contains(point.y), "\(phase)/\(seed): \(name)")
                }
                XCTAssertLessThan(p.you.y, Court.netY)
                XCTAssertGreaterThan(p.opponentLeft.y, Court.netY)
                XCTAssertLessThanOrEqual(p.opponentLeft.x, p.opponentRight.x,
                                         "\(phase)/\(seed): mirroring did not swap left and right")
            }
        }
    }
}
