import CoreGraphics

/// Keeps the four aim labels apart on screen.
///
/// De-colliding the aim points in COURT space is not enough and the first build
/// proved it: two rings two feet apart on the paint are two feet apart at
/// forty feet of depth, which is a handful of pixels. All four captions piled
/// into one unreadable stack near the far kitchen and the screenshot harness
/// reported, correctly, that the first option "was not hittable".
///
/// So the pills are laid out in screen space, where the constraint actually
/// lives, and a leader line runs back to the ring each one belongs to. The
/// rings stay exactly where the shot lands; only the captions move, the same
/// way a tactics board moves its labels off the players it is naming.
enum AimLabelLayout {

    /// How far above its ring a caption floats before collisions are resolved.
    static let lift: CGFloat = 34
    /// The step a colliding caption is pushed by, per pass.
    static let step: CGFloat = 7
    /// Breathing room required between two captions.
    static let gap: CGFloat = 5

    struct Placement {
        let index: Int
        /// The ring on the court, in screen points.
        let anchor: CGPoint
        /// Where the caption ended up.
        let label: CGPoint
    }

    /// `anchors` is one entry per option, nil when the ring projected behind
    /// the camera. `insets` keeps captions clear of the HUD at the top and the
    /// prompt at the bottom.
    static func place(
        anchors: [CGPoint?],
        labelSize: CGSize,
        in size: CGSize,
        topInset: CGFloat = 96,
        bottomInset: CGFloat = 96
    ) -> [Placement] {
        let halfW = labelSize.width / 2
        let halfH = labelSize.height / 2
        let minX = halfW + 8
        let maxX = max(minX, size.width - halfW - 8)
        let minY = topInset + halfH
        let maxY = max(minY, size.height - bottomInset - halfH)

        func clamp(_ p: CGPoint) -> CGPoint {
            CGPoint(x: min(max(p.x, minX), maxX), y: min(max(p.y, minY), maxY))
        }
        func rect(at p: CGPoint) -> CGRect {
            CGRect(x: p.x - halfW, y: p.y - halfH,
                   width: labelSize.width, height: labelSize.height)
                .insetBy(dx: -gap, dy: -gap)
        }

        // Farthest first. A near label drawn later ends up on top, which is the
        // only correct z-order when two overlap.
        let order = anchors.indices
            .filter { anchors[$0] != nil }
            .sorted { (anchors[$0]?.y ?? 0) < (anchors[$1]?.y ?? 0) }

        var taken: [CGRect] = []
        var placements: [Placement] = []

        for index in order {
            guard let anchor = anchors[index] else { continue }
            let start = clamp(CGPoint(x: anchor.x, y: anchor.y - lift))

            var candidate = start
            var moved = 0
            // Push toward the viewer first: down the screen is empty near court,
            // and a caption that drifts that way still points back up its
            // leader line at the ring it names.
            while taken.contains(where: { $0.intersects(rect(at: candidate)) }),
                  moved < 60, candidate.y < maxY {
                candidate.y += step
                moved += 1
            }
            if taken.contains(where: { $0.intersects(rect(at: candidate)) }) {
                candidate = start
                moved = 0
                while taken.contains(where: { $0.intersects(rect(at: candidate)) }),
                      moved < 60, candidate.y > minY {
                    candidate.y -= step
                    moved += 1
                }
            }
            candidate = clamp(candidate)
            taken.append(rect(at: candidate))
            placements.append(Placement(index: index, anchor: anchor, label: candidate))
        }
        return placements
    }
}
