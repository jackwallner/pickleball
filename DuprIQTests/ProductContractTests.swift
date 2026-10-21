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

    /// Pace and height are what tell the shots apart in the replay, so a
    /// drive must arrive before a dink, a dink before a drop, a drop before a
    /// lob, and the lob must still peak highest.
    func testReplayPaceAndHeightSeparateTheShots() {
        let order: [ShotType] = [.drive, .dink, .drop, .lob]
        let times = order.map(ShotFlight.airTime(for:))
        XCTAssertEqual(times, times.sorted(), "air time must rise drive < dink < drop < lob")
        XCTAssertEqual(Set(times).count, times.count)
        let h = 2.0
        XCTAssertGreaterThan(ShotFlight.apexHeight(for: .lob, contactHeight: h),
                             ShotFlight.apexHeight(for: .drop, contactHeight: h))
        XCTAssertGreaterThan(ShotFlight.apexHeight(for: .drop, contactHeight: h),
                             ShotFlight.apexHeight(for: .dink, contactHeight: h))
    }

    /// Fitting a replay to the screen may flatten a lob, but never into the
    /// tape, and a path that already fits is left exactly as it was.
    func testFittingAReplayNeverPutsItIntoTheNet() {
        let shot = Shot(.lob, .deepStraight)
        let flight = ShotFlight.make(
            shot, from: CourtPoint(x: 10, y: 4), contactHeight: 2,
            to: CourtPoint(x: 10, y: 40)
        )
        XCTAssertEqual(flight.fitted { _ in true }, flight)
        let flat = flight.fitted { _ in false }
        XCTAssertGreaterThanOrEqual(flat.heightAtNet ?? 0, ShotFlight.netHeight + 0.2 - 1e-9)
        XCTAssertLessThan(flat.samples.map { $0.height }.max() ?? 0, flight.samples.map { $0.height }.max() ?? 0)
    }

    /// A named trap never describes what the right answer did. A ball whose
    /// answer drove at the feet once told the player who drove elsewhere that
    /// they had attacked a ball that could not be attacked.
    func testATrapNeverContradictsTheRightAnswer() {
        for phase in RallyPhase.allCases {
            for seed in UInt64(1)...300 {
                let q = PositionGenerator.question(phase: phase, seed: seed)
                let best = q.verdict.best
                for (label, pattern) in MistakeCatalog.mistakes(for: q) {
                    let context = "\(phase) seed \(seed): \(label) named \(pattern.id), best \(best.label)"
                    if pattern.id == "attacked-a-low-ball" {
                        XCTAssertFalse([.drive, .speedUp, .putAway].contains(best.type), context)
                    }
                    if pattern.id == "ignored-the-open-middle" {
                        XCTAssertEqual(best.target, .middle, context)
                    }
                    if pattern.id == "lobbed-into-space-behind-nobody" {
                        XCTAssertNotEqual(best.type, .lob, context)
                    }
                }
            }
        }
    }
}
