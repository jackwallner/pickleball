import Foundation

/// The coaching principles every answer is filed under.
///
/// `ShotAdvisor` names a sentence-length rule on every verdict ("Dink into the
/// seam they left open"). This enum is the coarser family each of those rules
/// belongs to, and it is what "Your game" measures: nine families a player can
/// get better at, rather than fifteen phrasings of them.
enum Principle: String, Codable, CaseIterable, Identifiable, Sendable {
    case unattackable
    case getToTheLine
    case hitWhoIsntSet
    case middleSeam
    case longestDiagonal
    case returnDeep
    case reset
    case patience
    case finishDown

    var id: String { rawValue }

    /// The principle as a coach would say it on court.
    var displayName: String {
        switch self {
        case .unattackable: return "Keep the ball unattackable"
        case .getToTheLine: return "Get to the kitchen line"
        case .hitWhoIsntSet: return "Hit the player who isn't set"
        case .middleSeam: return "The middle solves problems"
        case .longestDiagonal: return "Cross-court is the longest ball"
        case .returnDeep: return "Return deep, then take the line"
        case .reset: return "Reset, don't counter-drive"
        case .patience: return "Patience beats a forced speed-up"
        case .finishDown: return "Finish a high ball downward"
        }
    }

    /// Short label for a choice chip, where the tag carries the rest.
    var shortName: String {
        switch self {
        case .unattackable: return "Unattackable ball"
        case .getToTheLine: return "Get to the line"
        case .hitWhoIsntSet: return "Hit who isn't set"
        case .middleSeam: return "Middle seam"
        case .longestDiagonal: return "Longest diagonal"
        case .returnDeep: return "Deep return"
        case .reset: return "Reset"
        case .patience: return "Patience"
        case .finishDown: return "Finish down"
        }
    }

    /// The part of the system this belongs to, shown the way an article number
    /// is shown in an exam-prep app: a short, stable place to file the idea.
    var tag: String {
        switch self {
        case .unattackable, .patience: return "The Soft Game"
        case .getToTheLine, .returnDeep: return "Court Position"
        case .hitWhoIsntSet, .middleSeam, .longestDiagonal: return "Target Selection"
        case .reset: return "Defense"
        case .finishDown: return "Offense"
        }
    }

    /// The tell that sends you to this principle. Written as the cue a player
    /// actually uses mid-rally, not as a definition.
    var howToSpot: String {
        switch self {
        case .unattackable:
            return "You are choosing between a ball that clears the net by a foot and one that clears it by three. Nobody at the kitchen line can hit down on a ball that arrives below net height, so the question is never how hard, it is how low it stays."
        case .getToTheLine:
            return "You are behind the kitchen line and the shot you are about to hit decides whether you get to walk in. Any time a shot buys you time to move up, that is what it is for. A winner from the baseline is a coin flip; the line is where points are actually won."
        case .hitWhoIsntSet:
            return "One opponent is at the line and the other is not, or one is still moving. Two identical white markers standing in different places is the whole read: the ball goes at the one whose feet have not stopped."
        case .middleSeam:
            return "Both opponents have drifted wide, or you are hitting from the middle with no diagonal to work with. A ball between two players is a ball neither one owns, and the middle is also where a poacher cannot get to first."
        case .longestDiagonal:
            return "You are at the kitchen, they are at the kitchen, nobody is out of position, and you need somewhere safe to put the ball. The cross-court diagonal is the longest distance on the court, so it clears the lowest part of the net with the most margin."
        case .returnDeep:
            return "You are returning serve. Depth is the only thing that matters here, because a deep return pins the serving team back and buys you the seconds you need to walk in behind it. Driving a return keeps you at the baseline, which is the mistake the phase exists to train out."
        case .reset:
            return "The ball is at your shoetops or coming at you with pace and you are not at the line yet. There is no offense available from here. Take the pace off, land it soft, and take the next ball from a better place."
        case .patience:
            return "The rally is even, nothing is high, and the urge is to make something happen. A dink rally is won by the player who is willing to hit one more, not by the player who forces the first speed-up off a ball below the net."
        case .finishDown:
            return "The ball is above net height and you are close enough to hit down on it. This is the one moment the soft game is over. Hit it downward at a body or a seam, not at a sideline."
        }
    }

    /// The family a verdict's rule belongs to.
    ///
    /// Keyed by the advisor's exact wording, so `ShotAdvisorTests` guards the
    /// table: a new rule with no family fails `testEveryVerdictHasAFamily`
    /// rather than silently dropping out of the mastery numbers.
    static func family(forVerdict principle: String) -> Principle? {
        verdictFamilies[principle]
    }

    /// The families at least one generated verdict can land in, in the order
    /// "Your game" lists them.
    static var measured: [Principle] {
        let used = Set(verdictFamilies.values)
        return allCases.filter(used.contains)
    }

    private static let verdictFamilies: [String: Principle] = [
        "Return deep, then take the line": .returnDeep,
        "Drop when they're set": .unattackable,
        "From the middle, drop straight": .getToTheLine,
        "A high ball is a drive, even on the third": .finishDown,
        "Drive at the player who isn't set": .hitWhoIsntSet,
        "Dink at the player who isn't set": .hitWhoIsntSet,
        "Attack the player who isn't set": .hitWhoIsntSet,
        "Dink into the seam they left open": .middleSeam,
        "Middle solves the poach problem": .middleSeam,
        "Cross-court is the longest, safest diagonal": .longestDiagonal,
        "Lob when they crowd the line": .longestDiagonal,
        "Reset off your shoetops, never drive": .reset,
        "Reset, don't counter-drive": .reset,
        "Finish down at the feet": .finishDown,
        "Finish through the seam": .finishDown,
        "Take the free ball through the seam": .finishDown,
        "Take the free ball in transition": .finishDown,
    ]
}
