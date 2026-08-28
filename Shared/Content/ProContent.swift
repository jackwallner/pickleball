import Foundation

/// The second paid room: the two ends of the pressure scale.
///
/// Attack and defense belong in one room because they are the same skill read
/// from opposite sides. Both come down to one question asked at contact: is
/// this ball above the net or below it? Players who lose rallies at 3.5 are
/// usually answering that question after they have chosen the shot.
enum ProContent {

    // MARK: - Attack

    static let attackCards: [Flashcard] = [
        Flashcard(
            id: "at-the-gate",
            frontTitle: "The gate for every attack",
            frontSubtitle: "One condition. What is it?",
            backTitle: "Contact above net height",
            backBody: "Everything else is detail. Above the net, your paddle face can point downward and the ball stays down; below it, the ball must rise and arrives hittable. No amount of pace, spin or confidence changes that geometry, which is why the height check has to happen before the shot choice and not after.",
            principle: Principle.finishDown.tag,
            choice: CardChoice("Contact above the net", "A clean look at it", answerIndex: 0)
        ),
        Flashcard(
            id: "at-target-body",
            frontTitle: "Where a put-away goes",
            frontSubtitle: "You have a high ball at the line. Sideline or body?",
            backTitle: "Body, or the seam",
            backBody: "You already have the angle; aiming at a line only adds the chance of missing it. A ball at the hip of the player closest to you, or into the seam between them, cannot be answered with a clean paddle face. The line is what you hit when you have no angle, and at the kitchen you always have one.",
            principle: Principle.finishDown.tag,
            choice: CardChoice("Body or seam", "The open sideline", answerIndex: 0)
        ),
        Flashcard(
            id: "at-speedup-cost",
            frontTitle: "What a speed-up costs",
            frontSubtitle: "It looks free. What are you giving up?",
            backTitle: "The first counter",
            backBody: "Speeding up hands the other team the next ball at pace, and hands are faster than legs. If your speed-up does not arrive below their paddle or at their body, you have started a hands battle from the worse side of it. A speed-up off a ball that was not sitting up is not aggression, it is volunteering.",
            principle: Principle.patience.tag
        ),
        Flashcard(
            id: "at-who-to-attack",
            frontTitle: "Which opponent to attack",
            frontSubtitle: "Both are reachable. Does it matter which?",
            backTitle: "The one who isn't set",
            backBody: "The read does not change just because the ball is now attackable. A player still moving, still recovering, or reaching across their body cannot get a paddle out in front in time. Attacking the set player is choosing the harder target while the easier one stands there.",
            principle: Principle.hitWhoIsntSet.tag,
            choice: CardChoice("The one who isn't set", "The one nearer to you", answerIndex: 0)
        ),
        Flashcard(
            id: "at-overhead-discipline",
            frontTitle: "The lob you get to answer",
            frontSubtitle: "They lob, you have an overhead. What is the miss?",
            backTitle: "Hitting it too hard, too fine",
            backBody: "An overhead is already a winning position, so the only way to lose it is to add risk. Hit it firmly at the middle of the court rather than flat out at a corner. Most missed overheads are missed long or wide by players trying to make a good position better.",
            principle: Principle.finishDown.tag
        ),
    ]

    static let attackQuiz: [QuizQuestion] = [
        QuizQuestion(
            id: "at-q-high-at-line",
            prompt: "Everyone is at the kitchen. Their dink floats and you can take it clearly above the net.",
            givens: [.ballHeight(.aboveNet), .you(.kitchen), .opponents("Both at the line")],
            choices: [
                "Hit down at the nearer opponent's body",
                "Hit flat at the open sideline",
                "Dink it back and keep the rally",
                "Lob it over them",
            ],
            answerIndex: 0,
            explanation: "You already have the downward angle, so the extra risk of aiming at a line buys nothing. A ball at the body gives them no room to get a paddle face on it. Dinking it back declines the one attackable ball the rally has produced.",
            principle: Principle.finishDown.tag
        ),
        QuizQuestion(
            id: "at-q-high-one-lagging",
            prompt: "You get a ball above the net at the line. Their left player is set; their right player is a couple of steps back and still moving.",
            givens: [.ballHeight(.aboveNet), .opponents("Left set, right still moving")],
            choices: [
                "Attack at the right opponent's feet",
                "Attack at the left opponent's body",
                "Attack the middle seam",
                "Dink it cross-court instead",
            ],
            answerIndex: 0,
            explanation: "Height gives you the attack; their feet decide the target. The player who is still moving cannot get their paddle out in front, so a hard ball at their feet is the highest-percentage finish on the court.",
            principle: Principle.hitWhoIsntSet.tag
        ),
        QuizQuestion(
            id: "at-q-low-speedup",
            prompt: "You are at the line and the ball reaches you just below the top of the net. You feel like you can drive through it.",
            givens: [.ballHeight(.belowNet), .you(.kitchen), .opponents("Both at the line")],
            choices: [
                "Keep it soft and low",
                "Speed it up at the nearer opponent",
                "Speed it up into the middle",
                "Drive it flat at the sideline",
            ],
            answerIndex: 0,
            explanation: "Below the net the ball must rise, so all three attacking options arrive above the net at two ready paddles. You would be starting a hands battle by handing them the first clean ball. Keep it low and wait for one that sits up.",
            principle: Principle.unattackable.tag
        ),
        QuizQuestion(
            id: "at-q-both-wide-high",
            prompt: "A ball sits up above the net. Both opponents are at the line but they have drifted well apart chasing the last few dinks.",
            givens: [.ballHeight(.aboveNet), .opponents("Both at the line, well apart")],
            choices: [
                "Drive it down through the seam",
                "Drive it at the left opponent's body",
                "Dink it into the seam instead",
                "Lob it deep",
            ],
            answerIndex: 0,
            explanation: "An attackable ball and an open seam is the best combination in the sport: neither player owns it, both have to reach, and the ball is arriving downward. Dinking into the same seam is a fine shot in a different situation, but not when you can hit down on it.",
            principle: Principle.middleSeam.tag
        ),
    ]

    // MARK: - Defense

    static let defenseCards: [Flashcard] = [
        Flashcard(
            id: "df-reset-definition",
            frontTitle: "What a reset is",
            frontSubtitle: "Describe it by what it does, not how it looks.",
            backTitle: "Pace off, lands soft, buys ground",
            backBody: "A reset absorbs the pace of an attacking ball and drops it in or near their kitchen so it cannot be attacked again. It wins nothing by itself; it converts a losing rally into a neutral one and lets you take the next ball from a better place. Held paddle, loose grip, no swing.",
            principle: Principle.reset.tag,
            choice: CardChoice("Takes pace off and lands soft", "Redirects their pace back", answerIndex: 0)
        ),
        Flashcard(
            id: "df-counter-trap",
            frontTitle: "The counter-drive trap",
            frontSubtitle: "They attacked you. Why not attack back?",
            backTitle: "You are the one below the net",
            backBody: "A ball attacked at you arrives low and fast, so countering means swinging up at pace, and the ball rises straight into the paddles of two players who are already set. Hands battles are won by whoever is above the net, and when you are defending that is not you.",
            principle: Principle.reset.tag
        ),
        Flashcard(
            id: "df-block-vs-reset",
            frontTitle: "Block or reset",
            frontSubtitle: "Both take pace off. What separates them?",
            backTitle: "Where the ball ends up",
            backBody: "A block just survives the ball; a reset survives it AND lands it short enough that they cannot attack the reply. If your soft ball lands mid-court it comes back harder. Aim for their kitchen, not merely for the other side of the net.",
            principle: Principle.reset.tag,
            choice: CardChoice("Where the ball lands", "How hard you swing", answerIndex: 0)
        ),
        Flashcard(
            id: "df-defensive-lob",
            frontTitle: "The defensive lob",
            frontSubtitle: "When is it a read rather than a panic?",
            backTitle: "Only against a team crowding the line",
            backBody: "A lob buys time, but it gives them an overhead unless they have nowhere to retreat. Against opponents pressed up against the kitchen line it is a genuine option; against anyone standing normally it converts a defendable rally into a lost one. Most defensive lobs are hit because the player did not want to reset.",
            principle: Principle.reset.tag
        ),
        Flashcard(
            id: "df-partner-position",
            frontTitle: "Defending as a pair",
            frontSubtitle: "Your partner gets pushed back. What do you do?",
            backTitle: "Go back with them",
            backBody: "A team split front-to-back gives up the middle and the ball behind the up player. If your partner is driven back, retreat with them and rebuild the line together. Staying up alone feels braver and loses the next two balls through the gap you just created.",
            principle: Principle.reset.tag,
            choice: CardChoice("Retreat with them", "Hold your position at the line", answerIndex: 0)
        ),
    ]

    static let defenseQuiz: [QuizQuestion] = [
        QuizQuestion(
            id: "df-q-shoetops",
            prompt: "You are in the transition zone moving forward. Their ball arrives at your shoetops with pace.",
            givens: [.ballHeight(.belowNet), .you(.transition), .opponents("Both at the line")],
            choices: [
                "Reset it softly into their kitchen",
                "Counter-drive it at the nearer opponent",
                "Lob it to buy time",
                "Speed it up into the middle",
            ],
            answerIndex: 0,
            explanation: "From below your knees with your weight moving there is no offense available. The reset lands soft, forces the next ball to come up, and lets you finish the walk in. Every other option sends a rising ball at two set opponents.",
            principle: Principle.reset.tag
        ),
        QuizQuestion(
            id: "df-q-pinned-baseline",
            prompt: "You are pinned at the baseline after a poor third. Their fourth comes back deep and low at you.",
            givens: [.ballHeight(.belowNet), .you(.baseline), .opponents("Both at the line")],
            choices: [
                "Drop it into their kitchen and start moving in",
                "Drive it hard down the line",
                "Lob it deep cross-court",
                "Dink it short and stay back",
            ],
            answerIndex: 0,
            explanation: "The situation has not changed just because the third shot failed: they are at the line, you are not, and the ball is low. Another drop is still the shot that lands unattackable and buys you the walk. Driving from the baseline into two set paddles is how a recoverable rally ends.",
            principle: Principle.getToTheLine.tag
        ),
        QuizQuestion(
            id: "df-q-crowding",
            prompt: "You are under pressure at the baseline. Both opponents are leaning hard over the kitchen line, right on top of the net.",
            givens: [.you(.baseline), .opponents("Both crowding the kitchen line")],
            choices: [
                "Lob over them",
                "Drop into the kitchen",
                "Drive at the middle",
                "Reset short and stay back",
            ],
            answerIndex: 0,
            explanation: "This is the one position where the lob is a read. A team pressed against the line has nowhere to retreat and no time to turn, so a good lob wins the rally outright. Against opponents standing normally the same shot hands them an overhead.",
            principle: Principle.getToTheLine.tag
        ),
        QuizQuestion(
            id: "df-q-partner-back",
            prompt: "Your partner has been driven back to the baseline while you are still at the kitchen line. The next ball is coming to them, not you.",
            givens: [.you(.kitchen), .partner(.baseline), .opponents("Both at the line")],
            choices: [
                "Retreat and rebuild the line with them",
                "Hold your position at the kitchen",
                "Move to the middle and poach",
                "Step back only if the ball comes to you",
            ],
            answerIndex: 0,
            explanation: "A team split front-to-back concedes the middle and the space behind the up player, and both are easy targets for opponents who are already at the line. Retreating costs you court position for one shot; staying costs you the point.",
            principle: Principle.reset.tag
        ),
    ]
}
