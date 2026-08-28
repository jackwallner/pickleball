import XCTest
@testable import DuprIQ

/// The contract for the four captions on the court.
///
/// This file exists because of a real failure, not a hypothetical one. The
/// first build de-collided the aim points in court feet, which is the wrong
/// space: two rings two feet apart on the paint are a handful of pixels apart
/// at forty feet of depth, so all four captions stacked into one pile and the
/// screenshot harness reported that the first option "was not hittable". An
/// option a player cannot tap is a broken question, and nothing else in the
/// suite would catch it.
final class AimLabelLayoutTests: XCTestCase {

    private let size = CGSize(width: 402, height: 874)
    private let label = CGSize(width: 118, height: 44)

    private func place(_ anchors: [CGPoint?]) -> [AimLabelLayout.Placement] {
        AimLabelLayout.place(anchors: anchors, labelSize: label, in: size)
    }

    private func rect(_ p: CGPoint) -> CGRect {
        CGRect(x: p.x - label.width / 2, y: p.y - label.height / 2,
               width: label.width, height: label.height)
    }

    /// The one that was broken. Four rings within a few points of each other,
    /// which is exactly what the far kitchen looks like from your own baseline.
    func testCaptionsNeverOverlapEvenWhenEveryRingIsInTheSamePlace() {
        let anchors: [CGPoint?] = [
            CGPoint(x: 200, y: 430),
            CGPoint(x: 203, y: 432),
            CGPoint(x: 198, y: 429),
            CGPoint(x: 201, y: 434),
        ]
        let placed = place(anchors)
        XCTAssertEqual(placed.count, 4)
        for i in placed.indices {
            for j in placed.indices where j > i {
                XCTAssertFalse(
                    rect(placed[i].label).intersects(rect(placed[j].label)),
                    "captions \(placed[i].index) and \(placed[j].index) overlap"
                )
            }
        }
    }

    /// Every caption has to sit fully on screen, clear of the HUD above and the
    /// prompt below. A pill half off the edge is an option nobody can hit,
    /// which was the other half of the same bug.
    func testEveryCaptionStaysInsideTheSafeArea() {
        let anchors: [CGPoint?] = [
            CGPoint(x: -80, y: 20),
            CGPoint(x: 480, y: 30),
            CGPoint(x: 200, y: 860),
            CGPoint(x: 0, y: 440),
        ]
        for placement in place(anchors) {
            let r = rect(placement.label)
            XCTAssertGreaterThanOrEqual(r.minX, 0)
            XCTAssertLessThanOrEqual(r.maxX, size.width)
            XCTAssertGreaterThanOrEqual(r.minY, 0)
            XCTAssertLessThanOrEqual(r.maxY, size.height)
        }
    }

    /// A ring that projected behind the camera has no caption, rather than a
    /// caption parked at the origin.
    func testRingsBehindTheCameraAreDropped() {
        let placed = place([CGPoint(x: 200, y: 400), nil, CGPoint(x: 260, y: 500), nil])
        XCTAssertEqual(Set(placed.map(\.index)), [0, 2])
    }

    /// The caption keeps a reference back to the ring it names, because a
    /// caption that had to move to avoid a neighbour is meaningless without the
    /// leader line that points home.
    func testEveryPlacementKeepsItsAnchor() {
        let anchors: [CGPoint?] = [
            CGPoint(x: 120, y: 400),
            CGPoint(x: 300, y: 520),
        ]
        for placement in place(anchors) {
            XCTAssertEqual(placement.anchor, anchors[placement.index])
        }
    }

    /// Well-separated rings should not be dragged around: a caption only moves
    /// when it has to.
    func testWellSpacedCaptionsSitAboveTheirOwnRings() {
        let anchors: [CGPoint?] = [
            CGPoint(x: 100, y: 300),
            CGPoint(x: 300, y: 560),
        ]
        for placement in place(anchors) {
            XCTAssertEqual(placement.label.x, placement.anchor.x, accuracy: 0.5)
            XCTAssertEqual(
                placement.label.y, placement.anchor.y - AimLabelLayout.lift, accuracy: 0.5
            )
        }
    }

    func testAnEmptyLayoutIsHandled() {
        XCTAssertTrue(place([]).isEmpty)
        XCTAssertTrue(place([nil, nil]).isEmpty)
    }
}
