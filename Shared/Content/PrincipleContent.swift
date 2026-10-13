import Foundation

/// The principle court's content.
///
/// The flashcards are generated from `Principle` itself rather than retyped,
/// because the enum is already the single source of the system's vocabulary and
/// a second copy of it in prose is a copy that drifts. The match questions are
/// authored: naming the principle behind a described situation is the skill,
/// and that cannot be derived from the enum.
enum PrincipleContent {

    static var principleCards: [Flashcard] {
        Principle.allCases.map { principle in
            Flashcard(
                id: "principle-\(principle.rawValue)",
                frontTitle: principle.displayName,
                frontSubtitle: "When does this one decide the shot?",
                backTitle: principle.shortName,
                backBody: principle.howToSpot,
                principle: principle.tag
            )
        }
    }

    static let principleMatch: [PrincipleMatchQuestion] = [
        PrincipleMatchQuestion(
            id: "pm-shoetops",
            scenario: "You are two steps inside the baseline, moving forward, and their fourth shot arrives at your shoetops with pace on it.",
            choices: [.reset, .finishDown, .longestDiagonal, .getToTheLine],
            answer: .reset,
            explanation: "There is no offense available from below your knees while you are still moving. Absorb the pace, land it in the kitchen, and take the next ball from a better place. The rally is not lost here unless you try to win it here."
        ),
        PrincipleMatchQuestion(
            id: "pm-both-wide",
            scenario: "Everyone is at the kitchen line. Both opponents have slid toward their own sidelines chasing the last two dinks, and there is daylight between them.",
            choices: [.middleSeam, .longestDiagonal, .patience, .unattackable],
            answer: .middleSeam,
            explanation: "A ball between two players is a ball neither one owns. Both have to decide, and the one who decides second arrives late. The middle is also the lowest part of the net, so the safest target is also the most awkward one to answer."
        ),
        PrincipleMatchQuestion(
            id: "pm-one-back",
            scenario: "You are dinking. Their left-side player is set at the line; the right-side player is still two steps back after chasing a wide ball.",
            choices: [.hitWhoIsntSet, .patience, .middleSeam, .finishDown],
            answer: .hitWhoIsntSet,
            explanation: "Two identical opponents standing in different places is the entire read. A ball at the feet of the player who is still moving forces a half-volley from a position they have not set up in. The player who is already set will handle anything you send them."
        ),
        PrincipleMatchQuestion(
            id: "pm-high-dink",
            scenario: "A dink comes back a little too high. You are at the line and can take it above the height of the net.",
            choices: [.finishDown, .patience, .unattackable, .longestDiagonal],
            answer: .finishDown,
            explanation: "This is the one moment the soft game is over. A ball above the net can be hit downward, and a ball hit downward cannot be countered from the kitchen. Take it at a body or a seam rather than at a sideline; you do not need the line when you already have the angle."
        ),
        PrincipleMatchQuestion(
            id: "pm-return",
            scenario: "You are receiving serve. The serve lands short and sits up invitingly at waist height.",
            choices: [.returnDeep, .finishDown, .getToTheLine, .hitWhoIsntSet],
            answer: .returnDeep,
            explanation: "The invitation is the trap. A short serve tempts a drive, and a drive keeps you at the baseline while the serving team walks in. A high, deep return pins them back and buys you the seconds to take the line yourself, which is the only thing the return is for."
        ),
        PrincipleMatchQuestion(
            id: "pm-third-both-set",
            scenario: "You are serving. Their return is deep, you are behind the baseline, and both opponents are established at the kitchen line.",
            choices: [.getToTheLine, .finishDown, .hitWhoIsntSet, .middleSeam],
            answer: .getToTheLine,
            explanation: "Against two set opponents a drive gives them a ball at chest height to hit down on. The third shot is not a scoring shot, it is transportation: arc it into the kitchen so it lands below the net and use the time it buys to walk in."
        ),
        PrincipleMatchQuestion(
            id: "pm-even-dink",
            scenario: "A dink rally has gone eight balls. Nothing is above the net, nobody is out of position, and you can feel yourself wanting to end it.",
            choices: [.patience, .middleSeam, .finishDown, .reset],
            answer: .patience,
            explanation: "The urge to make something happen is the error. Speeding up a ball below net height sends it rising into two paddles at the line. Hit one more good dink; the pop-up you are waiting for comes from their impatience, not yours."
        ),
        PrincipleMatchQuestion(
            id: "pm-safe-target",
            scenario: "Everyone is at the line, the ball is below net height, nobody is out of position, and you just need somewhere safe to put it.",
            choices: [.longestDiagonal, .middleSeam, .finishDown, .returnDeep],
            answer: .longestDiagonal,
            explanation: "The cross-court dink travels the longest distance on the court and crosses the net at its lowest point, so it has the most margin of any ball available. When no read is screaming at you, take the shot with the most court for error."
        ),
        PrincipleMatchQuestion(
            id: "pm-low-drive-temptation",
            scenario: "You are at the line. The ball is coming to you at about knee height and your partner is calling for you to speed it up.",
            choices: [.unattackable, .finishDown, .patience, .hitWhoIsntSet],
            answer: .unattackable,
            explanation: "Height decides this, not enthusiasm. A ball below the net has to travel upward to clear it, which means it arrives at their paddles above the net. You would be handing them the attack you were trying to take."
        ),
    ]
}
