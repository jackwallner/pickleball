import Foundation

/// A named reasoning error: the trap behind a tempting wrong shot.
struct MistakePattern: Hashable, Codable, Sendable {
    /// Stable key. Persisted, so renaming one resets that tally.
    let id: String
    /// `RallyPhase.rawValue` the trap was walked into, so a focus point can be
    /// generated from the right phase.
    let phase: String
    /// Second person, past tense, no scolding. Read immediately after a miss.
    let summary: String

    /// A few words for the HUD and "Your game".
    var title: String { MistakeCatalog.title(for: id) }
}

/// Names the reasoning error behind a wrong shot.
///
/// The generator already picks distractors a real player is tempted by, but a
/// tempting wrong answer with no name is just a wrong answer. Naming it is what
/// lets the app say "you drove a ball that was below the net" instead of
/// "incorrect", and what gives `targetedItems(for:count:)` something to aim at.
enum MistakeCatalog {

    /// Every named trap, keyed by id, so a persisted tally survives a rebuild
    /// of this table as long as the ids stay put.
    static func mistakes(for question: DrillQuestion) -> [String: MistakePattern] {
        var named: [String: MistakePattern] = [:]
        for shot in question.options where shot != question.verdict.best {
            guard let pattern = pattern(for: shot, in: question) else { continue }
            named[shot.label] = pattern
        }
        return named
    }

    /// The trap behind picking `shot` on this question, if it has a name.
    ///
    /// Judged against the right answer, not the position alone: a trap the
    /// best shot walks into as well is not a trap. Without that check a ball
    /// whose answer was "drive at their feet" told the player who drove to the
    /// backhand that they had attacked a ball that could not be attacked.
    static func pattern(for shot: Shot, in question: DrillQuestion) -> MistakePattern? {
        pattern(for: shot, in: question.position, best: question.verdict.best)
    }

    static func pattern(for shot: Shot, in position: RallyPosition, best: Shot) -> MistakePattern? {
        guard shot != best,
              let pattern = rawPattern(for: shot, in: position, best: best) else { return nil }
        if rawPattern(for: best, in: position, best: best)?.id == pattern.id { return nil }
        return pattern
    }

    private static func rawPattern(for shot: Shot, in position: RallyPosition, best: Shot) -> MistakePattern? {
        let phase = position.phase.rawValue

        // Attacking a ball that cannot be attacked is the single most common
        // error in the sport, and it is checkable from the height alone.
        if !position.ballHeight.isAttackable, position.phase != .serveReturn,
           !isNetHeightTransitionDrive(shot, in: position),
           shot.type == .drive || shot.type == .speedUp || shot.type == .putAway {
            return MistakePattern(
                id: "attacked-a-low-ball",
                phase: phase,
                summary: "You attacked a ball that was not above the net. There was nothing to hit down on, so that ball pops up and the point is theirs."
            )
        }

        // A soft ball off a high one is a missed chance, not a lost point,
        // and a hard deep return is a sound if worse return; both are
        // `ShotAdvisor.isPlayable`. A short return is the real mistake: it
        // lets the serving team walk in behind it.
        if position.phase == .serveReturn, shot.type == .drop {
            return MistakePattern(
                id: "returned-short",
                phase: phase,
                summary: "You dropped the return. A short ball lets the serving team move up behind it, and takes away the time a deep return buys you to reach the line."
            )
        }

        // A shot at the player who IS set, when the other one is still moving.
        if let lagging = position.laggingOpponentSide,
           [.drive, .speedUp, .putAway].contains(shot.type),
           let aimed = aimedOpponent(for: shot, in: position),
           aimed == lagging.opposite {
            return MistakePattern(
                id: "hit-the-player-who-was-set",
                phase: phase,
                summary: "You attacked the opponent who was already set. \(lagging.label.capitalizedFirst) had not made the line, and that is the one who cannot handle a hard ball at their feet."
            )
        }

        // Ignoring an open seam in favour of a body. Only a trap when the
        // answer took the seam: a reset or lob that is right for other
        // reasons does not make every other ball a missed middle.
        if position.isMiddleOpen, best.target == .middle, shot.target != .middle,
           [.drive, .speedUp, .putAway].contains(shot.type) {
            return MistakePattern(
                id: "ignored-the-open-middle",
                phase: phase,
                summary: "You attacked a body with the middle wide open. A ball in the seam is a ball neither player owns, and the biggest target on the court."
            )
        }

        // Counter-driving from the transition zone instead of resetting.
        if position.phase == .transition || position.phase == .defense,
           !isNetHeightTransitionDrive(shot, in: position),
           shot.type == .drive || shot.type == .speedUp {
            return MistakePattern(
                id: "counter-drove-under-pressure",
                phase: phase,
                summary: "You counter-drove from a position with no offense in it. Take the pace off, land it soft, and take the next ball from the line instead."
            )
        }

        // Lobbing as an escape hatch rather than a read.
        if shot.type == .lob, !position.opponentsBothAtKitchen {
            return MistakePattern(
                id: "lobbed-into-space-behind-nobody",
                phase: phase,
                summary: "You lobbed opponents who were not crowding the line. A lob only beats a team leaning in at the kitchen, with no time to turn and chase it."
            )
        }

        return nil
    }

    /// Short names, keyed by the same stable ids.
    static func title(for id: String) -> String {
        switch id {
        case "attacked-a-low-ball": return "Attacking a low ball"
        case "drove-the-return": return "Driving the return"
        case "hit-the-player-who-was-set": return "Attacking the set player"
        case "returned-short": return "Returning short"
        case "let-a-high-ball-go": return "Letting a high ball go"
        case "ignored-the-open-middle": return "Missing the open middle"
        case "counter-drove-under-pressure": return "Counter-driving under pressure"
        case "lobbed-into-space-behind-nobody": return "Lobbing a team that isn't crowding"
        default: return "A tempting wrong shot"
        }
    }

    /// Traps the catalog can still name. "drove-the-return" and
    /// "let-a-high-ball-go" were retired as lost points after a coach review;
    /// their titles stay so old tallies still read, but nothing targets them.
    static let allIDs = [
        "attacked-a-low-ball", "hit-the-player-who-was-set",
        "ignored-the-open-middle", "counter-drove-under-pressure",
        "lobbed-into-space-behind-nobody", "returned-short",
    ]

    /// A drive at the feet off a net-height ball from mid-court: a normal
    /// 3.5 to 4.0 shot, worse than the reset but not a mistake.
    static func isNetHeightTransitionDrive(_ shot: Shot, in position: RallyPosition) -> Bool {
        position.phase == .transition && position.ballHeight == .netHeight
            && shot.type == .drive && shot.target == .atFeet
    }

    private static func aimedOpponent(for shot: Shot, in position: RallyPosition) -> OpponentSide? {
        switch shot.target {
        case .crossCourtKitchen, .deepCrossCourt: return position.crossCourtOpponentSide
        case .straightKitchen, .deepStraight: return position.straightOpponentSide
        case .atFeet, .backhand: return position.laggingOpponentSide ?? position.crossCourtOpponentSide
        case .middle: return nil
        }
    }
}
