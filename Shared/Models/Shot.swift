import Foundation

/// The shot shapes a drill ever asks you to choose between.
///
/// Deliberately small. A position offers four candidates, so the list has to
/// stay coarse enough that two options are never the same idea wearing
/// different names.
enum ShotType: String, Sendable, CaseIterable, Identifiable {
    case deepReturn
    case drive
    case drop
    case dink
    case reset
    case speedUp
    case putAway
    case lob

    var id: String { rawValue }

    var label: String {
        switch self {
        case .deepReturn: return "Deep return"
        case .drive: return "Drive"
        case .drop: return "Third shot drop"
        case .dink: return "Dink"
        case .reset: return "Reset"
        case .speedUp: return "Speed up"
        case .putAway: return "Put it away"
        case .lob: return "Lob"
        }
    }

    var blurb: String {
        switch self {
        case .deepReturn: return "Deep, high, and follow it in"
        case .drive: return "Hard and flat through the gap"
        case .drop: return "Arc it into the kitchen and move up"
        case .dink: return "Soft, unattackable, over the net"
        case .reset: return "Take the pace off and land it soft"
        case .speedUp: return "Change the speed off a high ball"
        case .putAway: return "Finish it downward"
        case .lob: return "Over their heads to the baseline"
        }
    }
}

/// Where the ball is being sent. Kept in coaching language rather than
/// coordinates, because that is how the answer gets explained.
enum ShotTarget: String, Sendable, CaseIterable, Identifiable {
    case crossCourtKitchen
    case straightKitchen
    case middle
    case deepCrossCourt
    case deepStraight
    case atFeet
    case backhand

    var id: String { rawValue }

    /// Two or three words, for the moment a caption has to say WHERE as well
    /// as what. The long `label` is prose for the verdict card and does not fit
    /// on a pill over a court.
    var shortLabel: String {
        switch self {
        case .crossCourtKitchen: return "cross-court"
        case .straightKitchen: return "down the line"
        case .middle: return "up the middle"
        case .deepCrossCourt: return "deep cross"
        case .deepStraight: return "deep line"
        case .atFeet: return "at their feet"
        case .backhand: return "to the backhand"
        }
    }

    var label: String {
        switch self {
        case .crossCourtKitchen: return "cross-court kitchen"
        case .straightKitchen: return "straight into the kitchen"
        case .middle: return "up the middle"
        case .deepCrossCourt: return "deep cross-court"
        case .deepStraight: return "deep down the line"
        case .atFeet: return "at their feet"
        case .backhand: return "to the backhand"
        }
    }
}

/// One selectable answer: a shape plus a place to put it.
struct Shot: Hashable, Sendable, Identifiable {
    let type: ShotType
    let target: ShotTarget

    var id: String { "\(type.rawValue)-\(target.rawValue)" }

    var label: String { "\(type.label), \(target.label)" }

    init(_ type: ShotType, _ target: ShotTarget) {
        self.type = type
        self.target = target
    }
}
