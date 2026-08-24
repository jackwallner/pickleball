import Foundation

/// Court geometry for a standard doubles court, in feet.
///
/// Coordinates are always drawn from the drilling player's point of view:
/// `x` runs 0 (left sideline) to 20 (right sideline), `y` runs 0 (your
/// baseline) through 22 (the net) to 44 (their baseline). Every position the
/// generator emits and every zone the advisor reasons about uses this frame,
/// so a saved position renders the same way it was graded.
enum Court {
    static let width: Double = 20
    static let length: Double = 44
    static let netY: Double = 22

    /// The non-volley zone extends 7 ft from the net on each side.
    static let kitchenDepth: Double = 7
    static let ourKitchenLine: Double = netY - kitchenDepth      // 15
    static let theirKitchenLine: Double = netY + kitchenDepth    // 29

    static let centerX: Double = width / 2
}

/// Where a player is standing, bucketed the way coaching language buckets it.
///
/// The bucket is what the advisor reasons about. Exact feet only matter for
/// drawing the diagram, and for deciding which bucket someone falls into.
enum CourtZone: String, Sendable, CaseIterable {
    case kitchen
    case transition
    case baseline

    var label: String {
        switch self {
        case .kitchen: return "At the kitchen"
        case .transition: return "In transition"
        case .baseline: return "Back at the baseline"
        }
    }
}

/// Which half of the court a point sits in, from the drilling player's view.
enum CourtSide: String, Sendable {
    case near   // y < netY, the drilling team
    case far    // y > netY, the opponents
}

extension Court {
    /// Bucket a y coordinate into a zone. `side` decides which direction
    /// "toward the net" runs, so the same thresholds serve both teams.
    static func zone(forY y: Double, side: CourtSide) -> CourtZone {
        let distanceFromNet = side == .near ? (netY - y) : (y - netY)
        switch distanceFromNet {
        case ..<8.5: return .kitchen
        case ..<15: return .transition
        default: return .baseline
        }
    }

    static func side(forY y: Double) -> CourtSide {
        y < netY ? .near : .far
    }

    /// Clamp a point onto the playable surface so a generated position can
    /// never render a player standing outside the court.
    static func clamp(_ point: CourtPoint) -> CourtPoint {
        CourtPoint(
            x: min(max(point.x, 0.5), width - 0.5),
            y: min(max(point.y, 0.5), length - 0.5)
        )
    }
}

struct CourtPoint: Equatable, Sendable {
    var x: Double
    var y: Double

    init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    var side: CourtSide { Court.side(forY: y) }
    var zone: CourtZone { Court.zone(forY: y, side: side) }

    /// True when the point sits left of the center line from the drilling
    /// player's view. Used to work out which diagonal a cross-court ball takes.
    var isLeftHalf: Bool { x < Court.centerX }
}
