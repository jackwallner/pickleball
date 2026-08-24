import Foundation

/// Ball height at the moment you make contact, which is the single feature
/// that decides whether a ball is attackable.
enum BallHeight: String, Sendable, CaseIterable {
    case belowNet
    case netHeight
    case aboveNet

    var label: String {
        switch self {
        case .belowNet: return "Below net height"
        case .netHeight: return "About net height"
        case .aboveNet: return "Above net height"
        }
    }

    var isAttackable: Bool { self == .aboveNet }
}

/// The rally phase a position belongs to. Drills are grouped by this, and it
/// is also what the advisor branches on first.
enum RallyPhase: String, Sendable, CaseIterable, Identifiable {
    case serveReturn
    case thirdShot
    case transition
    case dinkRally
    case attack
    case defense

    var id: String { rawValue }

    var title: String {
        switch self {
        case .serveReturn: return "Return of serve"
        case .thirdShot: return "Third shot"
        case .transition: return "Transition zone"
        case .dinkRally: return "Dink rally"
        case .attack: return "Attack the high ball"
        case .defense: return "Playing defense"
        }
    }

    var subtitle: String {
        switch self {
        case .serveReturn: return "Where the point is really won"
        case .thirdShot: return "Drop or drive, and why"
        case .transition: return "Getting through no man's land"
        case .dinkRally: return "Patience and the right diagonal"
        case .attack: return "Recognising a ball you can finish"
        case .defense: return "Resetting from under pressure"
        }
    }
}

/// A complete, gradeable court situation.
///
/// Everything the advisor needs is on this struct: it is a pure value, so a
/// position can be generated, graded, stored and replayed with no hidden state.
struct RallyPosition: Equatable, Sendable, Identifiable {
    let id: String
    let phase: RallyPhase

    /// The drilling player, always on the near side.
    let you: CourtPoint
    let partner: CourtPoint
    let opponentLeft: CourtPoint
    let opponentRight: CourtPoint

    /// Where you are making contact, and how high the ball is.
    let contact: CourtPoint
    let ballHeight: BallHeight

    let yourScore: Int
    let theirScore: Int
    let isServingTeam: Bool

    var yourZone: CourtZone { you.zone }
    var partnerZone: CourtZone { partner.zone }
    var opponentLeftZone: CourtZone { opponentLeft.zone }
    var opponentRightZone: CourtZone { opponentRight.zone }

    /// True only when both opponents have established at the kitchen line.
    var opponentsBothAtKitchen: Bool {
        opponentLeftZone == .kitchen && opponentRightZone == .kitchen
    }

    /// The opponent who has not got to the line yet, if there is exactly one.
    /// This is the target a drive or a ball at the feet should go to.
    var laggingOpponent: CourtPoint? {
        let leftBack = opponentLeftZone != .kitchen
        let rightBack = opponentRightZone != .kitchen
        guard leftBack != rightBack else { return nil }
        return leftBack ? opponentLeft : opponentRight
    }

    var scoreLine: String {
        isServingTeam ? "\(yourScore)-\(theirScore), you're serving"
                      : "\(theirScore)-\(yourScore), they're serving"
    }
}
