import XCTest
@testable import DuprIQ

/// The contract for the four badges on the court.
///
/// This file exists because of a real failure, not a hypothetical one, and it
/// has now outlived two versions of that failure. The first build de-collided
/// the aim points in court feet, which is the wrong space: two rings two feet
/// apart on the paint are a handful of pixels apart at forty feet of depth, so
/// all four captions stacked into one pile and the screenshot harness reported
/// that the first option "was not hittable". The second laid the captions out
/// in screen space, which is the right space and still could not win, because
/// four 118 by 44 point pills do not fit around four rings inside the two
/// hundred point strip a standing eye sees the far court in. Every audit
/// screenshot showed a label sitting on the ring it named.
///
/// The text is in the option panel now and what is left on the court is a 26
/// point numbered badge, small enough to sit AT its ring rather than beside it.
/// These tests pin the two things that still have to be true: badges do not
/// land on top of each other, and a badge never hides under the chrome.
final class AimLabelLayoutTests: XCTestCase {

    private let size = CGSize(width: 402, height: 874)
    private let top: CGFloat = 104
    private let bottom: CGFloat = 314

    private func place(_ anchors: [CGPoint?]) -> [AimLabelLayout.Placement] {
        AimLabelLayout.place(anchors: anchors, in: size, topInset: top, bottomInset: bottom)
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = a.x - b.x, dy = a.y - b.y
        return (dx * dx + dy * dy).squareRoot()
    }

    /// The one that was broken. Four rings within a few points of each other,
    /// which is exactly what the far kitchen looks like from your own baseline.
    func testBadgesNeverOverlapEvenWhenEveryRingIsInTheSamePlace() {
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
                XCTAssertGreaterThanOrEqual(
                    distance(placed[i].badge, placed[j].badge),
                    AimLabelLayout.badgeSize,
                    "badges \(placed[i].index) and \(placed[j].index) overlap"
                )
            }
        }
    }

    /// Every badge has to sit fully on screen and clear of both chrome bands.
    /// A badge under the HUD or under the option panel is a target nobody can
    /// see, which was the other half of the same bug.
    func testEveryBadgeStaysInsideTheVisibleBand() {
        let anchors: [CGPoint?] = [
            CGPoint(x: -80, y: 20),
            CGPoint(x: 480, y: 30),
            CGPoint(x: 200, y: 860),
            CGPoint(x: 0, y: 440),
        ]
        let half = AimLabelLayout.badgeSize / 2
        for placement in place(anchors) {
            XCTAssertGreaterThanOrEqual(placement.badge.x - half, 0)
            XCTAssertLessThanOrEqual(placement.badge.x + half, size.width)
            XCTAssertGreaterThanOrEqual(placement.badge.y - half, top)
            XCTAssertLessThanOrEqual(placement.badge.y + half, size.height - bottom)
        }
    }

    /// A ring that projected behind the camera has no badge, rather than a
    /// badge parked at the origin.
    func testRingsBehindTheCameraAreDropped() {
        let placed = place([CGPoint(x: 200, y: 400), nil, CGPoint(x: 260, y: 500), nil])
        XCTAssertEqual(Set(placed.map(\.index)), [0, 2])
    }

    /// The badge keeps a reference back to the ring it names, because a badge
    /// that had to move to avoid a neighbour is meaningless without the tether
    /// that points home.
    func testEveryPlacementKeepsItsAnchor() {
        let anchors: [CGPoint?] = [
            CGPoint(x: 120, y: 400),
            CGPoint(x: 300, y: 520),
        ]
        for placement in place(anchors) {
            XCTAssertEqual(placement.anchor, anchors[placement.index])
        }
    }

    /// Well-separated rings are not touched. A badge sits ON its ring unless a
    /// neighbour forces it off, which is the whole reason the text moved to the
    /// panel: there is no longer anything to lay out on the court.
    func testWellSpacedBadgesSitExactlyOnTheirRings() {
        let anchors: [CGPoint?] = [
            CGPoint(x: 100, y: 300),
            CGPoint(x: 300, y: 480),
        ]
        for placement in place(anchors) {
            XCTAssertEqual(placement.badge.x, placement.anchor.x, accuracy: 0.5)
            XCTAssertEqual(placement.badge.y, placement.anchor.y, accuracy: 0.5)
            XCTAssertFalse(placement.isOffset)
        }
    }

    /// A badge never travels far enough to look like it belongs to a different
    /// ring. Two overlapping badges are recoverable, because the panel button
    /// and the ring underneath both still work; a badge sitting on somebody
    /// else's ring is a wrong answer waiting to happen.
    func testABadgeIsNeverPushedFarFromItsOwnRing() {
        let anchors: [CGPoint?] = (0..<4).map { CGPoint(x: 200 + CGFloat($0), y: 400) }
        for placement in place(anchors) {
            XCTAssertLessThanOrEqual(
                distance(placement.badge, placement.anchor),
                AimLabelLayout.maximumNudge + AimLabelLayout.separation / 3,
                "badge \(placement.index) drifted off its ring"
            )
        }
    }

    /// The panel is a map of the court: top row is the two targets further away,
    /// bottom row the two nearer ones, each row left to right. If this ordering
    /// ever went to option order, the buttons would stop corresponding to the
    /// rings and the numbers would be doing all the work on their own.
    func testThePanelIsLaidOutLikeTheCourt() {
        let anchors: [CGPoint?] = [
            CGPoint(x: 300, y: 300),   // 0: far right
            CGPoint(x: 100, y: 500),   // 1: near left
            CGPoint(x: 120, y: 310),   // 2: far left
            CGPoint(x: 320, y: 505),   // 3: near right
        ]
        let rows = AimLabelLayout.panelOrder(place(anchors))
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[0].map(\.index), [2, 0], "the far row is not left to right")
        XCTAssertEqual(rows[1].map(\.index), [1, 3], "the near row is not left to right")
    }

    /// An odd number of options still lays out, because the primer draws two.
    func testAnOddNumberOfOptionsStillRows() {
        let rows = AimLabelLayout.panelOrder(place([
            CGPoint(x: 100, y: 300), CGPoint(x: 300, y: 320), CGPoint(x: 200, y: 500),
        ]))
        XCTAssertEqual(rows.map(\.count), [2, 1])
    }

    func testAnEmptyLayoutIsHandled() {
        XCTAssertTrue(place([]).isEmpty)
        XCTAssertTrue(place([nil, nil]).isEmpty)
        XCTAssertTrue(AimLabelLayout.panelOrder([]).isEmpty)
    }
}
