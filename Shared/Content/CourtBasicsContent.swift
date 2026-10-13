import Foundation

/// The free opening court: the court, the rules that actually cost points, and
/// the vocabulary every other court assumes you have.
///
/// This court is deliberately not "how to hold a paddle". Someone who downloads
/// a shot-selection trainer already plays. What they usually do not have is the
/// precise version of the rules that decide close rallies, and the shared words
/// for the parts of the court that the rest of the app uses without explaining.
enum CourtBasicsContent {

    static let courtCards: [Flashcard] = [
        Flashcard(
            id: "cb-kitchen",
            frontTitle: "The kitchen",
            frontSubtitle: "How deep is it, and what is actually forbidden?",
            backTitle: "Seven feet, and only volleys",
            backBody: "The non-volley zone runs seven feet back from the net on both sides, sideline to sideline. Standing in it is legal. What is illegal is volleying from it, and that includes any part of your momentum carrying you in after the hit. You may step in all day to play a ball that has bounced.",
            principle: Principle.getToTheLine.tag,
            choice: CardChoice("Seven feet", "Ten feet", answerIndex: 0)
        ),
        Flashcard(
            id: "cb-ready-position",
            frontTitle: "\"At the line\"",
            frontSubtitle: "Nobody stands with their toes on the kitchen line. So where?",
            backTitle: "A paddle's length behind it",
            backBody: "Players who are \"at the line\" stand about a foot to eighteen inches back from it, close enough to volley anything and far enough not to fault on momentum. This app treats anyone within about eight and a half feet of the net as being at the line, which is the same thing coaches mean when they say a player is up.",
            principle: Principle.getToTheLine.tag
        ),
        Flashcard(
            id: "cb-transition",
            frontTitle: "The transition zone",
            frontSubtitle: "Also called no man's land. Why is it bad?",
            backTitle: "Every ball arrives at your feet",
            backBody: "Between the kitchen line and the baseline, balls land at your shoetops rather than in front of you or on the full. You cannot volley comfortably and you cannot let it bounce comfortably. It is not a place to stand, it is a place to move through, which is why the shot that gets you through it matters more than the shot that wins from it.",
            principle: Principle.getToTheLine.tag,
            choice: CardChoice("A place to move through", "A place to defend from", answerIndex: 0)
        ),
        Flashcard(
            id: "cb-two-bounce",
            frontTitle: "The two-bounce rule",
            frontSubtitle: "Which two balls must bounce?",
            backTitle: "The serve and the return",
            backBody: "The serve must bounce before the returning team plays it, and the return must bounce before the serving team plays it. That is the whole rule, and it is the reason the serving team starts the point at a disadvantage: they are stuck at the baseline for one extra shot while the returners walk in.",
            principle: Principle.returnDeep.tag,
            choice: CardChoice("Serve and return", "Serve only", answerIndex: 0)
        ),
        Flashcard(
            id: "cb-why-serving-loses",
            frontTitle: "Why the serving team is behind",
            frontSubtitle: "They hit first. How is that a disadvantage?",
            backTitle: "The two-bounce rule pins them back",
            backBody: "Because the return has to bounce, the serving team cannot move in behind their serve. The returners can. So the point starts with one team at the line and one at the baseline, and the third shot exists entirely to fix that. Points are won at the kitchen, and the serving team has to travel there.",
            principle: Principle.getToTheLine.tag
        ),
        Flashcard(
            id: "cb-attackable",
            frontTitle: "What makes a ball attackable",
            frontSubtitle: "One feature decides it. Which?",
            backTitle: "Contact above net height",
            backBody: "Not speed, not spin, not where it lands. If you can make contact above the top of the net you can hit downward, and a downward ball cannot be countered from the kitchen. If you cannot, every shot you hit must travel upward to clear the net, and upward balls arrive hittable. This single test drives most of the answers in this app.",
            principle: Principle.unattackable.tag,
            choice: CardChoice("Contact above the net", "Ball speed", answerIndex: 0)
        ),
        Flashcard(
            id: "cb-stacking-language",
            frontTitle: "Straight and cross-court",
            frontSubtitle: "From your contact point, which opponent is which?",
            backTitle: "The diagonal is the long one",
            backBody: "The opponent diagonally opposite your contact is your cross-court target; the one straight ahead of you is your straight target. The diagonal is the longer ball across the lower middle of the net, which is why it is the safer default. Hitting from near the centre line, though, the two lengths are nearly equal and the diagonal stops being an advantage.",
            principle: Principle.longestDiagonal.tag
        ),
        Flashcard(
            id: "cb-score-call",
            frontTitle: "The three-number score",
            frontSubtitle: "\"Eight, four, two.\" What is the third number?",
            backTitle: "Which server you are",
            backBody: "Serving team's score, receiving team's score, then whether you are the first or second server for your side. Only the serving team scores. The third number is not decoration: it tells both teams how close the serving team is to losing the serve, which changes how much risk is worth taking.",
            principle: Principle.patience.tag,
            choice: CardChoice("Which server you are", "Games won", answerIndex: 0)
        ),
    ]

    static let rulesQuiz: [QuizQuestion] = [
        QuizQuestion(
            id: "cb-q-volley-momentum",
            prompt: "You volley a ball while standing behind the kitchen line, and your follow-through carries your foot into the kitchen after the ball has left your paddle. What is the call?",
            choices: [
                "Fault: momentum carried you in",
                "Legal: the ball was gone before you stepped in",
                "Legal: only both feet in is a fault",
                "Fault only if you touch the line itself",
            ],
            answerIndex: 0,
            explanation: "Momentum counts. If the act of volleying carries you into the non-volley zone, it is a fault even though the ball had already left the paddle. This is why players volley from a foot back rather than right on the line.",
            principle: Principle.getToTheLine.tag
        ),
        QuizQuestion(
            id: "cb-q-bounce-in-kitchen",
            prompt: "A dink bounces in the kitchen. You step fully into the kitchen and hit it off the bounce. What is the call?",
            choices: [
                "Legal: the ball bounced first",
                "Fault: you cannot stand in the kitchen",
                "Fault: you must retreat before hitting",
                "Legal only if you exit immediately after",
            ],
            answerIndex: 0,
            explanation: "The zone forbids volleys, not presence. A ball that has bounced can be played from anywhere, including with both feet planted inside the kitchen. Stepping in for a low dink is normal, correct, and something most improving players do too little.",
            principle: Principle.getToTheLine.tag
        ),
        QuizQuestion(
            id: "cb-q-return-depth",
            prompt: "You return serve. Which return gives your team the most advantage?",
            choices: [
                "High and deep, and you follow it to the line",
                "Hard and flat at the server's feet",
                "Short and soft to pull them forward",
                "A lob well over the baseline",
            ],
            answerIndex: 0,
            explanation: "Height is time, and depth is distance. A high, deep return keeps the serving team behind the baseline and gives you the seconds you need to walk all the way in. A hard return arrives sooner, which means it gives YOU less time and leaves you stranded mid-court.",
            principle: Principle.returnDeep.tag
        ),
        QuizQuestion(
            id: "cb-q-third-shot-purpose",
            prompt: "What is the third shot of a rally actually for?",
            choices: [
                "Buying the time to get to the kitchen line",
                "Winning the point outright",
                "Forcing an immediate error",
                "Keeping the opponents pinned at the baseline",
            ],
            answerIndex: 0,
            explanation: "The third shot is transportation, not offense. The serving team is stuck at the baseline by the two-bounce rule, and the third shot's job is to be unattackable enough that they can walk in behind it. Treating it as a winner is the most common way a serving team loses a rally.",
            principle: Principle.getToTheLine.tag
        ),
        QuizQuestion(
            id: "cb-q-who-scores",
            prompt: "You are receiving. You win a long rally with a clean put-away. What happens to the score?",
            choices: [
                "Nothing scores; your side wins the serve",
                "You score a point",
                "You score and keep receiving",
                "The point is replayed",
            ],
            answerIndex: 0,
            explanation: "Only the serving team can score. Winning a rally as the receiving team wins you the serve, not a point. This is why the receiving team can afford patience: a lost rally costs them nothing on the scoreboard, while the serving team is one error from handing the serve back.",
            principle: Principle.patience.tag
        ),
        QuizQuestion(
            id: "cb-q-erne-position",
            prompt: "Your opponents are both pressed right up against the kitchen line, leaning in. Which shot does that position invite?",
            choices: [
                "A lob over their heads",
                "A hard drive at the closer one",
                "A cross-court dink",
                "A drop into the middle of the kitchen",
            ],
            answerIndex: 0,
            explanation: "A team crowding the line has nowhere to retreat to. That is the one position where a lob is a read rather than a panic shot. Against opponents standing normally, a lob just hands them an overhead, which is why it is the wrong answer nearly everywhere else in this app.",
            principle: Principle.getToTheLine.tag
        ),
    ]
}
