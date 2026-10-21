import XCTest
@testable import DuprIQ

/// The promises the product makes that no generator test would notice
/// breaking: every answer is filed under a principle, every replay of a right
/// answer clears the net, and the four options never read the same.
final class ProductContractTests: XCTestCase {

    private func questions(perPhase: Int = 300) -> [DrillQuestion] {
        RallyPhase.allCases.flatMap { phase in
            (UInt64(1)...UInt64(perPhase)).map { PositionGenerator.question(phase: phase, seed: $0 &* 7_919) }
        }
    }

    func testEveryVerdictHasAFamily() {
        for q in questions() {
            XCTAssertNotNil(Principle.family(forVerdict: q.verdict.principle), q.verdict.principle)
        }
    }

    /// Two options that both read "Drive" was the first capture run's clearest
    /// bug report. A shared shot shape must always carry its place.
    func testNoTwoOptionsShareACaption() {
        for q in questions() {
            let captions = ShotAiming.captions(for: q.options).map { "\($0.title)|\($0.detail ?? "")" }
            XCTAssertEqual(Set(captions).count, captions.count, q.position.id)
        }
    }

    func testAtMostTwoOptionsShareAShotShape() {
        for q in questions() {
            let counts = Dictionary(grouping: q.options, by: \.type).values.map(\.count)
            XCTAssertLessThanOrEqual(counts.max() ?? 0, 2, q.options.map(\.label).joined(separator: " / "))
        }
    }

    func testEveryReplayedRightAnswerClearsTheNet() {
        for q in questions(perPhase: 120) {
            let landing = ShotAiming.aimPoints(
                for: q.options, in: q.position, answer: q.answer, answerTarget: q.verdict.targetOpponent
            )[q.answerIndex]
            let flight = ShotFlight.make(
                q.answer, from: q.position.contact, contactHeight: 2.9, to: landing
            )
            XCTAssertFalse(flight.endsInNet)
            let atNet = try! XCTUnwrap(flight.heightAtNet)
            XCTAssertGreaterThan(atNet, ShotFlight.netHeight, q.position.id)
            XCTAssertEqual(flight.samples.last?.point, landing)
        }
    }

    func testANettedShotStopsAtTheNet() {
        let q = PositionGenerator.question(phase: .dinkRally, seed: 4)
        let flight = ShotFlight.make(
            Shot(.drive, .atFeet), from: q.position.contact, contactHeight: 1.7,
            to: CourtPoint(x: 10, y: 30), intoNet: true
        )
        XCTAssertTrue(flight.endsInNet)
        XCTAssertTrue(flight.samples.allSatisfy { $0.point.y < CourtGeometry.netY })
    }

    func testEveryTrapHasAName() {
        for id in MistakeCatalog.allIDs {
            XCTAssertNotEqual(MistakeCatalog.title(for: id), MistakeCatalog.title(for: "unknown"), id)
        }
    }

    func testTheBrandCarriesNoRatingTrademark() {
        for text in [AppBrand.name, AppBrand.proName] {
            XCTAssertFalse(text.localizedCaseInsensitiveContains("DUPR"), text)
        }
        XCTAssertTrue(AppBrand.disclaimer.contains("Not affiliated"))
    }
}
