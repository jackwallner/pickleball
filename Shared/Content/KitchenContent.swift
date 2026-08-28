import Foundation

/// The second free room: the soft game.
///
/// This is the room that makes the app free-tier worth having on its own. Most
/// players below 4.0 lose rallies at the kitchen for one of three reasons, and
/// all three are decisions rather than strokes: they attack a ball that was
/// never attackable, they aim at a body when a seam was open, or they run out
/// of patience one ball before their opponent does.
enum KitchenContent {

    static let dinkCards: [Flashcard] = [
        Flashcard(
            id: "kg-what-is-a-dink",
            frontTitle: "What a dink actually is",
            frontSubtitle: "Define it by outcome, not by how it looks.",
            backTitle: "A ball that lands unattackable",
            backBody: "A dink is any soft ball that lands in or near their kitchen and arrives at or below net height. That is the entire definition. It is not about a slow swing or a pretty arc; a dink that sits up is not a dink, it is a gift, and a firm ball that lands low is doing the job.",
            principle: Principle.unattackable.tag,
            choice: CardChoice("Lands unattackable", "Has a slow swing", answerIndex: 0)
        ),
        Flashcard(
            id: "kg-net-height",
            frontTitle: "Why height beats everything",
            frontSubtitle: "Two balls, same speed, different heights. Why does one lose the point?",
            backTitle: "You cannot hit down on a low ball",
            backBody: "A ball contacted below the net has to travel upward to clear it, so it arrives at the other player somewhere above the net, where they can hit down on it. That is the whole mechanism. Every decision in the soft game reduces to keeping your ball below their contact point and waiting for them to fail to do the same.",
            principle: Principle.unattackable.tag
        ),
        Flashcard(
            id: "kg-cross-court-default",
            frontTitle: "The default dink",
            frontSubtitle: "Nothing is out of position and nothing is high. Where does it go?",
            backTitle: "Cross-court",
            backBody: "The cross-court dink covers the longest distance available and crosses the net at its lowest point, in the middle. More distance and a lower net is more margin, which is exactly what you want on a shot you may have to hit twenty times in a rally. It also pulls your opponent wide, which is how seams open in the first place.",
            principle: Principle.longestDiagonal.tag,
            choice: CardChoice("Cross-court", "Straight ahead", answerIndex: 0)
        ),
        Flashcard(
            id: "kg-middle-seam",
            frontTitle: "When the middle is right",
            frontSubtitle: "What has to be true for the seam to beat a body?",
            backTitle: "They have drifted apart",
            backBody: "Once the two opponents have separated, a ball between them belongs to neither. Both hesitate, one arrives late, and the reply comes back from a stretched position. The middle is also the lowest part of the net. Against two opponents standing normally, though, the middle is simply the shortest ball you can hit and one of them will step across and take it.",
            principle: Principle.middleSeam.tag
        ),
        Flashcard(
            id: "kg-who-isnt-set",
            frontTitle: "The player who isn't set",
            frontSubtitle: "One is at the line, one is still walking in. Which do you hit?",
            backTitle: "The one still moving",
            backBody: "A player who has not stopped cannot get low, cannot get their paddle out in front, and has to half-volley from wherever their feet happen to be. Put the ball at their feet. The set player will handle whatever you give them, so hitting to them is choosing the harder opponent for no reason.",
            principle: Principle.hitWhoIsntSet.tag,
            choice: CardChoice("The one still moving", "The one at the line", answerIndex: 0)
        ),
        Flashcard(
            id: "kg-backhand-target",
            frontTitle: "The backhand as a target",
            frontSubtitle: "When is aiming at the backhand worth doing?",
            backTitle: "When you are already forcing a stretch",
            backBody: "A backhand dink from a comfortable position is a shot every decent player has. A backhand from a stretch, or one they have to reach across their body for, is not. So the backhand is a tiebreaker on top of a real read, never the read itself: pull them wide first, then take the next one to the backhand side.",
            principle: Principle.hitWhoIsntSet.tag
        ),
        Flashcard(
            id: "kg-patience",
            frontTitle: "The count nobody keeps",
            frontSubtitle: "How many dinks does a typical won rally take?",
            backTitle: "More than you want it to",
            backBody: "Rallies at the line routinely run ten or fifteen balls before someone gives up a high one. Players lose them by deciding, around ball six, that they should be doing something. The discipline is not passivity: you are still working the angles, still moving them. You are just refusing to be the one who hits the first upward ball.",
            principle: Principle.patience.tag,
            choice: CardChoice("More than you want", "Two or three", answerIndex: 0)
        ),
        Flashcard(
            id: "kg-let-it-go",
            frontTitle: "The ball you should let go",
            frontSubtitle: "A dink is drifting toward the sideline near the baseline side of the kitchen.",
            backTitle: "Watch it land",
            backBody: "Kitchen rallies are played on a small target and balls that look wide usually are. Reaching for one you did not have to play turns a free point into a stretched reply from outside the court. If you have to lean past your outside foot to reach it, let it bounce and look.",
            principle: Principle.patience.tag
        ),
    ]

    static let kitchenQuiz: [QuizQuestion] = [
        QuizQuestion(
            id: "kg-q-low-speedup",
            prompt: "You are at the line. The ball reaches you at about knee height, below the top of the net. You have a clean look at it.",
            givens: [.ballHeight(.belowNet), .you(.kitchen), .opponents("Both at the line")],
            choices: [
                "Dink it cross-court and wait",
                "Speed it up at the closer opponent",
                "Drive it flat down the line",
                "Lob it over both of them",
            ],
            answerIndex: 0,
            explanation: "A clean look at a low ball is still a low ball. Anything you hit hard from below the net rises on its way over and arrives at two paddles that are already up. Keep it low, keep the rally, and take the attack when they hand you one above the net.",
            principle: Principle.unattackable.tag
        ),
        QuizQuestion(
            id: "kg-q-both-wide",
            prompt: "Everyone is at the line. Your last two dinks pulled both opponents toward their sidelines and there is a clear gap between them.",
            givens: [.ballHeight(.belowNet), .opponents("Both at the line, well apart")],
            choices: [
                "Dink into the seam between them",
                "Dink cross-court again",
                "Speed it up at the left opponent",
                "Dink at the right opponent's feet",
            ],
            answerIndex: 0,
            explanation: "The seam is the payoff for the two dinks that opened it. Neither player owns the ball, both have to decide, and the one who decides second arrives late. Going cross-court again is not wrong, it just declines the opening you spent two shots creating.",
            principle: Principle.middleSeam.tag
        ),
        QuizQuestion(
            id: "kg-q-one-lagging",
            prompt: "You are dinking. Their left player is set at the kitchen line. Their right player is two steps behind it, still recovering from a wide ball.",
            givens: [.ballHeight(.belowNet), .opponents("Left set, right still recovering")],
            choices: [
                "Dink at the right opponent's feet",
                "Dink cross-court to the left opponent",
                "Speed it up at the right opponent",
                "Dink into the middle",
            ],
            answerIndex: 0,
            explanation: "A player who is still moving cannot get low or get their paddle in front. A soft ball at their feet forces a half-volley from a position they have not set up in. Speeding up at them sounds tempting but the ball is below the net, so it rises and they get to block it back from a paddle already at chest height.",
            principle: Principle.hitWhoIsntSet.tag
        ),
        QuizQuestion(
            id: "kg-q-high-dink",
            prompt: "Their dink floats. You are at the line and can take it a few inches above the top of the net.",
            givens: [.ballHeight(.aboveNet), .you(.kitchen), .opponents("Both at the line")],
            choices: [
                "Hit down at the nearer opponent's feet",
                "Dink it back cross-court",
                "Lob it deep",
                "Reset it into the kitchen",
            ],
            answerIndex: 0,
            explanation: "This is the ball the whole soft game was waiting for. Above the net means you can hit downward, and a downward ball at a body cannot be countered from the kitchen. Dinking it back is not safe, it is a declined opportunity that hands the rally back to even.",
            principle: Principle.finishDown.tag
        ),
        QuizQuestion(
            id: "kg-q-middle-contact",
            prompt: "You are dinking from near the centre line, everyone is at the kitchen, and both opponents are in normal position with no gap between them.",
            givens: [.ballHeight(.belowNet), .side("Near the centre line"), .opponents("Both at the line, normal spacing")],
            choices: [
                "Dink straight ahead and stay low",
                "Try to angle it sharply cross-court",
                "Speed it up into the middle",
                "Lob the far opponent",
            ],
            answerIndex: 0,
            explanation: "From the middle there is no long diagonal to use: both balls travel about the same distance, so the cross-court shot gives up its usual margin and asks you to create a sharp angle you do not have. Hit the straight ball, keep it low, and wait for a contact point out wide before looking for the diagonal again.",
            principle: Principle.longestDiagonal.tag
        ),
        QuizQuestion(
            id: "kg-q-patience",
            prompt: "A dink rally has run about ten balls. Nothing has been above the net, nobody is out of position, and your partner is getting restless.",
            givens: [.ballHeight(.belowNet), .opponents("Both set, nobody out of position")],
            choices: [
                "Hit another good dink and keep waiting",
                "Speed up the next ball to break the pattern",
                "Lob to change the rhythm",
                "Drive at the middle",
            ],
            answerIndex: 0,
            explanation: "Nothing in the situation has changed, so nothing in the answer should. Each of the alternatives converts a neutral rally into an upward ball at two ready paddles. The player who wins a long kitchen exchange is the one who was willing to hit one more, not the one who found something clever.",
            principle: Principle.patience.tag
        ),
    ]
}
