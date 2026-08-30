import CoreGraphics
import Foundation

/// Keeps the four aim BADGES apart on screen.
///
/// This used to lay out four caption pills, and the audit killed that idea
/// outright. A pill is roughly 118 by 44 points; four rings in the far kitchen
/// project into a strip about 200 points tall on a portrait phone, because a
/// court seen from a standing eye is a plane viewed at a grazing angle and
/// twenty feet of depth is a couple of hundred pixels. Four pills cannot be
/// placed around four rings in that strip, and every screenshot showed the
/// same failure: the label naming a target sitting squarely on top of it, or on
/// top of the one next to it. Nudging in screen space cannot fix an input that
/// is already impossible.
///
/// So the text moved off the court entirely, into the option panel underneath
/// it, and what is left on each ring is a 26 point numbered badge that matches
/// the numbered button in the panel. A badge is smaller than the ring it sits
/// in, so it can be placed AT the ring rather than beside it, which removes the
/// leader lines and the whole class of "which pill means which ring" problem
/// with them. All this has to do now is stop two badges overlapping when two
/// rings land within a badge's width of each other.
enum AimLabelLayout {

    /// The drawn diameter of a badge, in points.
    static let badgeSize: CGFloat = 26
    /// Centres closer than this are pushed apart.
    static let separation: CGFloat = 30
    /// How far a badge may be moved from its ring before it stops being a label
    /// for that ring. Past this the badge is left where it is: two overlapping
    /// badges are recoverable (the panel button is still there, and the ring is
    /// still tappable), a badge sitting on the wrong ring is not.
    static let maximumNudge: CGFloat = 34

    struct Placement {
        let index: Int
        /// The ring on the court, in screen points.
        let anchor: CGPoint
        /// Where the badge ended up. Equal to `anchor` unless a neighbour
        /// forced it away.
        let badge: CGPoint

        /// True when the badge had to leave its ring, which is when the view
        /// draws a short tether so the pairing stays obvious.
        var isOffset: Bool {
            abs(badge.x - anchor.x) > 0.5 || abs(badge.y - anchor.y) > 0.5
        }
    }

    /// `anchors` is one entry per option, nil when the ring projected behind
    /// the camera. `topInset` and `bottomInset` keep badges out from under the
    /// HUD and the option panel; a badge under either is a target the player
    /// cannot see and cannot press.
    static func place(
        anchors: [CGPoint?],
        in size: CGSize,
        topInset: CGFloat = 0,
        bottomInset: CGFloat = 0
    ) -> [Placement] {
        guard size.width > 0, size.height > 0 else { return [] }
        let half = badgeSize / 2
        let minX = half + 6
        let maxX = max(minX, size.width - half - 6)
        let minY = topInset + half + 6
        let maxY = max(minY, size.height - bottomInset - half - 6)

        func clamp(_ p: CGPoint) -> CGPoint {
            CGPoint(x: min(max(p.x, minX), maxX), y: min(max(p.y, minY), maxY))
        }

        // Start every badge on its own ring, then push the cluster apart.
        //
        // The first version walked one badge at a time away from the single
        // neighbour it happened to be touching, and it could not solve four
        // rings landing on one square foot of paint: each badge escaped one
        // clash straight into another and hit its travel limit still
        // overlapping. Relaxing all of them together converges in a handful of
        // passes and lands a tight cluster on a small circle, which is the
        // shape that reads.
        let order = anchors.indices.filter { anchors[$0] != nil }
        var badges: [Int: CGPoint] = [:]
        for (rank, index) in order.enumerated() {
            guard let anchor = anchors[index] else { continue }
            // Break exact ties deterministically. Rings that project to the
            // very same point produce a zero push vector, so the cluster would
            // sit on top of itself for ever; a one point spoke per badge is
            // enough for the relaxation below to take hold, and it depends only
            // on option order.
            let angle = Double(rank) * 2 * .pi / Double(max(order.count, 1))
            badges[index] = clamp(CGPoint(
                x: anchor.x + CGFloat(cos(angle)),
                y: anchor.y + CGFloat(sin(angle))
            ))
        }

        for _ in 0..<24 {
            var settled = true
            for index in order {
                guard let anchor = anchors[index], var point = badges[index] else { continue }
                var pushX: CGFloat = 0, pushY: CGFloat = 0
                for other in order where other != index {
                    guard let neighbour = badges[other] else { continue }
                    let gap = distance(point, neighbour)
                    guard gap < separation, gap > 0.0001 else { continue }
                    let scale = (separation - gap) / gap / 2
                    pushX += (point.x - neighbour.x) * scale
                    pushY += (point.y - neighbour.y) * scale
                }
                guard abs(pushX) > 0.01 || abs(pushY) > 0.01 else { continue }
                settled = false
                point = clamp(CGPoint(x: point.x + pushX, y: point.y + pushY))
                // Never far enough to look like somebody else's ring. Two
                // overlapping badges are recoverable, because the panel button
                // and the ring itself both still answer; a badge on the wrong
                // ring is a wrong answer waiting to happen.
                let drift = distance(point, anchor)
                if drift > maximumNudge {
                    let scale = maximumNudge / drift
                    point = CGPoint(
                        x: anchor.x + (point.x - anchor.x) * scale,
                        y: anchor.y + (point.y - anchor.y) * scale
                    )
                }
                badges[index] = point
            }
            if settled { break }
        }

        return order.compactMap { index in
            guard let anchor = anchors[index], let badge = badges[index] else { return nil }
            // A badge that never had to move goes back exactly onto its ring,
            // rather than keeping the one point tie-breaking spoke.
            let settled = distance(badge, clamp(anchor)) < 1.6 ? clamp(anchor) : badge
            return Placement(index: index, anchor: anchor, badge: settled)
        }
    }

    /// The reading order for the option panel: the two farther targets on the
    /// top row, the two nearer ones below, each row left to right.
    ///
    /// The panel is a map, not a list. A button in the top-left of the grid is
    /// the ring in the top-left of the court, so the pairing survives even
    /// before anyone reads a number, and the numbers are the backstop rather
    /// than the mechanism.
    static func panelOrder(_ placements: [Placement]) -> [[Placement]] {
        guard !placements.isEmpty else { return [] }
        let byDepth = placements.sorted { $0.anchor.y < $1.anchor.y }
        let rowCount = (byDepth.count + 1) / 2
        return (0..<rowCount).map { row in
            let slice = byDepth[(row * 2)..<min(row * 2 + 2, byDepth.count)]
            return slice.sorted { $0.anchor.x < $1.anchor.x }
        }
    }

    private static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = a.x - b.x, dy = a.y - b.y
        return (dx * dx + dy * dy).squareRoot()
    }
}
