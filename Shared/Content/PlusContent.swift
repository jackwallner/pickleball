import Foundation

/// The extra sets inside the free rooms.
///
/// These are additions, not confiscations. Every drill that was free before is
/// still free; these are more original questions with the same mechanics,
/// aimed at the situations where two principles look like they collide and a
/// player has to know which one wins.
enum PlusContent {

    static let basicsExtras: [QuizQuestion] = [
        QuizQuestion(
            id: "px-b-serve-fault",
            prompt: "You serve. The ball clips the top of the net and lands cleanly in the correct service box. What is the call?",
            choices: [
                "Play on: it is a legal serve",
                "Let: replay the serve",
                "Fault: net contact on the serve",
                "Fault only if it lands in the kitchen",
            ],
            answerIndex: 0,
            explanation: "Pickleball has no lets on the serve. A serve that touches the net and lands in the correct box is live and the point continues. Players who stop expecting a replay lose the rally they were still in.",
            principle: Principle.patience.tag
        ),
        QuizQuestion(
            id: "px-b-kitchen-serve",
            prompt: "Your serve lands in the correct box but its first bounce is inside the non-volley zone line.",
            choices: [
                "Fault: a serve may not land in the kitchen",
                "Legal: any ball in the service box counts",
                "Legal if it does not touch the line",
                "Let: replay the point",
            ],
            answerIndex: 0,
            explanation: "The service box excludes the non-volley zone, and the line counts as in the zone. A serve landing there is a fault even though it is otherwise on your opponent's side of the court.",
            principle: Principle.patience.tag
        ),
        QuizQuestion(
            id: "px-b-partner-swap",
            prompt: "Mid-rally, you and your partner cross over so you end up on the sides you did not start the point on.",
            choices: [
                "Legal: positions only matter at the serve",
                "Fault: you must stay on your own side",
                "Legal only for the receiving team",
                "Fault unless you swap back before the next shot",
            ],
            answerIndex: 0,
            explanation: "Court positions are only fixed at the moment of the serve. Once the ball is live, partners may play from anywhere on their side, which is what makes switching and poaching legal tactics rather than faults.",
            principle: Principle.middleSeam.tag
        ),
        QuizQuestion(
            id: "px-b-score-before",
            prompt: "You are serving at 8-4-2. What does the last number tell your opponents?",
            choices: [
                "One more error and the serve changes hands",
                "Your team has served eight times",
                "You have won two games",
                "There are two points left to play",
            ],
            answerIndex: 0,
            explanation: "The third number is the server number. Being the second server means your side has already lost one serve this turn, so the next lost rally hands the serve over. That changes how much risk is worth taking on the very next ball.",
            principle: Principle.patience.tag
        ),
    ]

    static let principleExtras: [PrincipleMatchQuestion] = [
        PrincipleMatchQuestion(
            id: "px-pm-high-but-unset",
            scenario: "A ball sits up above the net. You could hit down on it, and one opponent is also still walking in from a wide ball.",
            choices: [.hitWhoIsntSet, .finishDown, .middleSeam, .longestDiagonal],
            answer: .hitWhoIsntSet,
            explanation: "Both principles apply and they do not conflict: the height tells you that you may attack, their feet tell you where. The two principles are answering different questions, and the target question is the one still open."
        ),
        PrincipleMatchQuestion(
            id: "px-pm-middle-contact-wide-opponents",
            scenario: "You are hitting from near the centre line. The opponents have drifted apart and there is a gap between them.",
            choices: [.middleSeam, .longestDiagonal, .patience, .unattackable],
            answer: .middleSeam,
            explanation: "From the middle there is no long diagonal to take, so the usual cross-court default gives up nothing when you decline it. The seam is directly in front of you and it is the shot the position is offering."
        ),
        PrincipleMatchQuestion(
            id: "px-pm-lob-temptation",
            scenario: "You are stuck at the baseline, tired of resetting, and the opponents are standing in normal position a foot behind the kitchen line.",
            choices: [.getToTheLine, .reset, .finishDown, .patience],
            answer: .getToTheLine,
            explanation: "The lob is only a read against a team crowding the line, and these opponents are not. The shot that still needs hitting is the one that lands unattackable and buys you the walk in, however many times you have already had to hit it."
        ),
        PrincipleMatchQuestion(
            id: "px-pm-attack-vs-patience",
            scenario: "Eleven dinks in, a ball finally comes back a few inches above the top of the net while you are at the line.",
            choices: [.finishDown, .patience, .unattackable, .reset],
            answer: .finishDown,
            explanation: "Patience is what earned this ball; it is not a reason to decline it. The discipline in a dink rally is about not attacking balls below the net, and this one is above it. Passing on a genuinely attackable ball returns the rally to even and wastes the eleven shots that produced it."
        ),
    ]

    static let kitchenExtras: [QuizQuestion] = [
        QuizQuestion(
            id: "px-k-wide-then-middle",
            prompt: "Your last dink pulled the cross-court opponent well outside the sideline. Their partner has shaded across to help cover.",
            givens: [.ballHeight(.belowNet), .opponents("One pulled wide, partner shaded across")],
            choices: [
                "Dink behind the shading partner, down their line",
                "Dink cross-court again to the same player",
                "Speed it up at the wide player",
                "Dink into the middle",
            ],
            answerIndex: 0,
            explanation: "When one opponent shades across to cover, the space they left is behind them down the line. The middle is exactly where they have just moved to, so the seam has closed while the line has opened.",
            principle: Principle.middleSeam.tag
        ),
        QuizQuestion(
            id: "px-k-backhand-stretch",
            prompt: "You have already pulled an opponent wide. The next ball can go to their forehand in front of them, or to their backhand across their body.",
            givens: [.ballHeight(.belowNet), .opponents("One already stretched wide")],
            choices: [
                "To the backhand, across their body",
                "To the forehand, in front of them",
                "Straight at their feet",
                "Back cross-court to their partner",
            ],
            answerIndex: 0,
            explanation: "A backhand from a comfortable position is a shot everyone has; a backhand reached across the body from a stretch is not. The backhand is a tiebreaker applied on top of a real read, and here the stretch is the read.",
            principle: Principle.hitWhoIsntSet.tag
        ),
        QuizQuestion(
            id: "px-k-let-it-go",
            prompt: "A dink is drifting toward the sideline and you would have to lean well past your outside foot to reach it.",
            givens: [.ballHeight(.belowNet), .you(.kitchen)],
            choices: [
                "Let it bounce and watch it",
                "Reach and dink it back cross-court",
                "Reach and speed it up",
                "Step across and take it as a volley",
            ],
            answerIndex: 0,
            explanation: "Kitchen rallies are played on a small target and balls that look wide usually are. Reaching converts a possible free point into a stretched reply from outside the court, which is a rally you are then defending for no reason.",
            principle: Principle.patience.tag
        ),
        QuizQuestion(
            id: "px-k-partner-pulled-wide",
            prompt: "Your partner has been pulled wide off the court to play a dink. The ball is coming back toward the middle.",
            givens: [.ballHeight(.belowNet), .partner(.kitchen), .you(.kitchen)],
            choices: [
                "Slide toward the middle to cover their gap",
                "Hold your position and cover your own line",
                "Move forward to poach the next ball",
                "Drop back to the transition zone",
            ],
            answerIndex: 0,
            explanation: "Doubles partners move as a unit connected by an invisible rope. When one is pulled wide, the other slides with them to keep the gap between the two of you constant. Holding your own line leaves the middle open, which is where good opponents are already aiming.",
            principle: Principle.middleSeam.tag
        ),
    ]
}
