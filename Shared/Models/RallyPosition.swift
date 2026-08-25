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

/// Which opponent a shot is aimed at. The diagram draws two identical white
/// markers, so the answer has to be able to name one of them.
enum OpponentSide: String, Sendable, CaseIterable {
    case left
    case right

    var label: String {
        switch self {
        case .left: return "the left opponent"
        case .right: return "the right opponent"
        }
    }

    /// What the marker itself is captioned with on the diagram.
    var marker: String {
        switch self {
        case .left: return "L"
        case .right: return "R"
        }
    }

    var opposite: OpponentSide { self == .left ? .right : .left }
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

    func opponent(_ side: OpponentSide) -> CourtPoint {
        side == .left ? opponentLeft : opponentRight
    }

    func zone(of side: OpponentSide) -> CourtZone { opponent(side).zone }

    /// True only when both opponents have established at the kitchen line.
    var opponentsBothAtKitchen: Bool {
        opponentLeftZone == .kitchen && opponentRightZone == .kitchen
    }

    /// The opponent who has not got to the line yet, if there is exactly one.
    /// This is the target a drive or a ball at the feet should go to.
    var laggingOpponentSide: OpponentSide? {
        let leftBack = opponentLeftZone != .kitchen
        let rightBack = opponentRightZone != .kitchen
        guard leftBack != rightBack else { return nil }
        return leftBack ? .left : .right
    }

    var laggingOpponent: CourtPoint? { laggingOpponentSide.map(opponent) }

    // MARK: - Lateral reads
    //
    // The diagram shows four sets of feet, so the answer has to be allowed to
    // change when those feet move sideways. Everything below is what turns an
    // exact x into something a coach would actually say out loud.

    /// The opponent diagonally opposite your contact point. Your cross-court
    /// ball goes to this one.
    var crossCourtOpponentSide: OpponentSide {
        contact.isLeftHalf ? .right : .left
    }

    /// The opponent straight ahead of your contact point.
    var straightOpponentSide: OpponentSide { crossCourtOpponentSide.opposite }

    /// How far apart the two opponents are standing, laterally.
    var opponentSpread: Double { abs(opponentLeft.x - opponentRight.x) }

    /// Both of them have drifted wide, so the seam between them is the target
    /// rather than either body.
    var isMiddleOpen: Bool { opponentSpread >= Court.openMiddleGap }

    /// Contact near the center line has no long diagonal available.
    var isContactNearMiddle: Bool { contact.isNearMiddle }

    /// Plain-language description of where you are hitting from, used in the
    /// situation line and the accessible court description.
    var contactSideLabel: String {
        if contact.isNearMiddle { return "from the middle" }
        return contact.isLeftHalf ? "from the left side" : "from the right side"
    }

    var scoreLine: String {
        isServingTeam ? "\(yourScore)-\(theirScore), you're serving"
                      : "\(theirScore)-\(yourScore), they're serving"
    }

    /// The same rally seen from the other side of the center line.
    ///
    /// Left and right swap because the marker that was nearest the left
    /// sideline is now nearest the right one. Nothing about the shot changes,
    /// which is exactly the property `ShotAdvisorTests` pins down.
    var mirrored: RallyPosition {
        RallyPosition(
            id: id + "-m", phase: phase,
            you: you.mirrored,
            partner: partner.mirrored,
            opponentLeft: opponentRight.mirrored,
            opponentRight: opponentLeft.mirrored,
            contact: contact.mirrored,
            ballHeight: ballHeight,
            yourScore: yourScore, theirScore: theirScore,
            isServingTeam: isServingTeam
        )
    }
}
