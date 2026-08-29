import Foundation

/// Where a shot actually lands, in court feet.
///
/// This exists because the app stopped asking players to pick a sentence off a
/// list and started asking them to aim. `ShotTarget` used to be pure coaching
/// language ("cross-court kitchen") with no geometry behind it; the moment the
/// four options became four places on a rendered court, that language needed a
/// point. Keeping the mapping here, as a pure function of the position, means
/// the renderer, the hit-testing and the tests all agree on where a shot goes.
///
/// Everything is mirror-symmetric with `RallyPosition.mirrored`, because the
/// whole app rests on the property that reflecting a court reflects the answer
/// and changes nothing else. `ShotTargetingTests` pins that down.
extension Shot {

    /// The point on the far side this shot is aimed at.
    ///
    /// `preferring` is the opponent the graded verdict names, when there is
    /// one. Shots that go AT a player ("at their feet", "to the backhand") need
    /// to know which player, and the advisor is the only thing that actually
    /// knows; the fallback below is the same read the advisor uses, so a
    /// distractor still lands somewhere a coach would recognise.
    func landingPoint(
        in position: RallyPosition, preferring side: OpponentSide? = nil
    ) -> CourtPoint {
        let aimed = side ?? position.laggingOpponentSide ?? position.crossCourtOpponentSide
        let opponent = position.opponent(aimed)

        // Depth bands, from the drilling player's end.
        //
        // A ball "into the kitchen" lands a couple of feet past the net, not on
        // the kitchen line: aiming at the line itself is how a drop turns into
        // a pop-up, and drawing the puck there would teach the wrong target.
        let kitchenDepth = CourtGeometry.netY + 2.6
        let deepDepth = CourtGeometry.length - 4.0

        // Lateral bands. The cross-court half is whichever half the contact is
        // NOT in, which is the same rule `crossCourtOpponentSide` uses.
        let contactIsLeft = position.contact.isLeftHalf
        let crossX = contactIsLeft ? CourtGeometry.width * 0.75 : CourtGeometry.width * 0.25
        let straightX = contactIsLeft ? CourtGeometry.width * 0.25 : CourtGeometry.width * 0.75

        switch target {
        case .crossCourtKitchen:
            return clamped(x: crossX, y: kitchenDepth)
        case .straightKitchen:
            return clamped(x: straightX, y: kitchenDepth)
        case .middle:
            return clamped(x: CourtGeometry.centerX, y: kitchenDepth + 0.8)
        case .deepCrossCourt:
            return clamped(x: crossX, y: deepDepth)
        case .deepStraight:
            return clamped(x: straightX, y: deepDepth)
        case .atFeet:
            // Just in front of the player's shoes, on our side of them, which
            // is the ball that actually jams someone.
            return clamped(x: opponent.x, y: opponent.y - 1.4)
        case .backhand:
            // Right-handed opponents face us, so their left hand (the backhand
            // side) appears on OUR right, i.e. at a higher x. This is an
            // assumption the app states out loud in the coaching copy rather
            // than pretending to model handedness it never asked about.
            return clamped(x: opponent.x + 2.4, y: max(opponent.y - 1.0, kitchenDepth))
        }
    }

    /// Keeps a landing point inside the far court, never on our side of the
    /// net and never off the paint. A puck drawn outside the lines would be
    /// asking the player to aim at a shot that is out.
    private func clamped(x: Double, y: Double) -> CourtPoint {
        CourtPoint(
            x: min(max(x, 1.2), CourtGeometry.width - 1.2),
            y: min(max(y, CourtGeometry.netY + 1.2), CourtGeometry.length - 1.2)
        )
    }
}

/// The four aim points for one generated question, de-collided.
///
/// Two options can genuinely share a target: the attack phase offers both
/// "Put it away, at their feet" and "Drive, at their feet", and those really do
/// go to the same square foot of court. Drawing one puck on top of another
/// would make one of the four options unpickable, so shots that land within
/// `mergeRadius` are fanned apart laterally in a stable order. The labels carry
/// the shot SHAPE, which is what actually separates them.
enum ShotAiming {
    /// Two landing points closer than this are treated as the same place.
    static let mergeRadius: Double = 2.5
    /// How far apart a fanned cluster spreads, per step. Four options at this
    /// spacing span 5.7 feet, which always fits between the sidelines.
    static let fanStep: Double = 1.9

    /// The furthest a fan can move a ring from where the shot actually lands.
    /// The camera fit in `CourtCamera` has to allow for this, or a ring that
    /// was fanned outward ends up off the edge of the frame.
    static let maximumFanOffset: Double = 3.0

    /// Aim points for each option, in the same order as `options`.
    static func aimPoints(
        for options: [Shot], in position: RallyPosition, answer: Shot? = nil,
        answerTarget: OpponentSide? = nil
    ) -> [CourtPoint] {
        var points = options.map { shot in
            shot.landingPoint(
                in: position,
                // Only the graded answer knows which opponent the verdict
                // meant; a distractor falls back to the positional read.
                preferring: shot == answer ? answerTarget : nil
            )
        }

        // Group by proximity, keeping the first-seen point as the cluster's
        // anchor so the result never depends on iteration order beyond the
        // caller's own option order.
        var clusters: [[Int]] = []
        for index in points.indices {
            if let match = clusters.firstIndex(where: { cluster in
                guard let anchor = cluster.first else { return false }
                return distance(points[anchor], points[index]) < mergeRadius
            }) {
                clusters[match].append(index)
            } else {
                clusters.append([index])
            }
        }

        for cluster in clusters where cluster.count > 1 {
            // Lay the cluster out around its own centre, in x order, then slide
            // the whole run inside the sidelines.
            //
            // The first version added a fixed offset to each member and clamped
            // each one independently, which quietly collapsed the fan whenever
            // the cluster sat near a sideline: both members clamped to the same
            // edge and ended up closer together than they started. Shifting the
            // run as a whole keeps the spacing whatever the clamp does.
            let ordered = cluster.sorted { points[$0].x < points[$1].x }
            let centre = ordered.reduce(0.0) { $0 + points[$1].x } / Double(ordered.count)
            let span = Double(ordered.count - 1) * fanStep

            var laid: [Double] = ordered.indices.map { offset in
                centre + Double(offset) * fanStep - span / 2
            }
            let lowest = 1.2, highest = CourtGeometry.width - 1.2
            if let first = laid.first, first < lowest {
                let shift = lowest - first
                laid = laid.map { $0 + shift }
            }
            if let last = laid.last, last > highest {
                let shift = last - highest
                laid = laid.map { $0 - shift }
            }
            for (offset, index) in ordered.enumerated() {
                points[index] = CourtPoint(x: laid[offset], y: points[index].y)
            }
        }

        return points
    }

    /// The caption for each option, in the same order.
    ///
    /// The caption says the SHAPE only, because the place is the ring, and
    /// printing "cross-court kitchen" on a pill sitting on the cross-court
    /// kitchen hands back the answer the render is asking someone to find.
    ///
    /// But a question can legitimately offer the same shape to two different
    /// places, and the third shot does it constantly: a drive at their feet and
    /// a drive down the line are a real decision. Captioned by shape alone
    /// those are two pills both reading "Drive", which is not a hint withheld,
    /// it is a question with two options nobody can tell apart. So the place is
    /// added only to the options where it is the thing separating them.
    static func captions(for options: [Shot]) -> [(title: String, detail: String?)] {
        options.map { shot in
            let shared = options.filter { $0.type == shot.type }.count > 1
            return (shot.type.label, shared ? shot.target.shortLabel : nil)
        }
    }

    private static func distance(_ a: CourtPoint, _ b: CourtPoint) -> Double {
        ((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y)).squareRoot()
    }
}
