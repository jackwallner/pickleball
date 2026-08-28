import Foundation

/// The first paid room: the third shot and the walk to the line.
///
/// This is where a paid tier earns its keep, because the third shot is the
/// single most consequential decision in doubles and the one most players get
/// wrong by reflex rather than by reasoning. The drop/drive choice is not a
/// preference, it is a read of four sets of feet.
enum TransitionContent {

    static let thirdShotCards: [Flashcard] = [
        Flashcard(
            id: "ts-drop-purpose",
            frontTitle: "What the drop is for",
            frontSubtitle: "It rarely wins the point. So why hit it?",
            backTitle: "It buys the walk to the line",
            backBody: "A third shot drop arcs into their kitchen and lands below the net, so nobody can hit down on it. The reply has to come up, and while it travels you cover fifteen feet. The drop's job is to convert the serving team's structural disadvantage into an even rally at the line. Judging it by winners is judging it by the wrong thing entirely.",
            principle: Principle.getToTheLine.tag,
            choice: CardChoice("Buys time to move in", "Wins the point", answerIndex: 0)
        ),
        Flashcard(
            id: "ts-drive-purpose",
            frontTitle: "What the drive is for",
            frontSubtitle: "When is hard the right answer on a third?",
            backTitle: "Against feet that aren't set",
            backBody: "A drive works when someone is not ready to receive it: an opponent still walking in, or a ball that has sat up high enough that you can hit through it rather than up at it. Against two set opponents at the line, a drive arrives at chest height in front of two ready paddles, which is the definition of a ball you should not have hit.",
            principle: Principle.hitWhoIsntSet.tag
        ),
        Flashcard(
            id: "ts-height-decides",
            frontTitle: "What decides drop or drive",
            frontSubtitle: "Two things. In what order?",
            backTitle: "Ball height first, then their feet",
            backBody: "Height is the gate: if the ball has sat up above the net you can drive it, because you are hitting through it rather than lifting it. If it has not, the only question left is whether someone is out of position, and if nobody is, it is a drop. Reading their feet before you read the height is how players end up driving balls off their shoetops.",
            principle: Principle.unattackable.tag,
            choice: CardChoice("Height, then their feet", "Their feet, then height", answerIndex: 0)
        ),
        Flashcard(
            id: "ts-middle-drop",
            frontTitle: "Dropping from the middle",
            frontSubtitle: "You are hitting a third from near the centre line. Which target?",
            backTitle: "Straight, not angled",
            backBody: "From the middle there is no long diagonal available, so the cross-court drop gives up its margin and asks for an angle you do not have from there. Drop it straight into the kitchen in front of you. Save the diagonal for contacts out wide, where the extra distance is real.",
            principle: Principle.longestDiagonal.tag
        ),
        Flashcard(
            id: "ts-transition-feet",
            frontTitle: "Moving through the transition zone",
            frontSubtitle: "Do you run all the way in behind the drop?",
            backTitle: "Move, then split-step",
            backBody: "Take a few steps in and split-step as they make contact, wherever you have got to. Running blind through the zone means the ball arrives while your weight is moving forward, and you cannot reset a ball you meet mid-stride. Two controlled advances beat one sprint, and it is fine to spend a shot in transition as long as you are not standing there.",
            principle: Principle.getToTheLine.tag,
            choice: CardChoice("Move, then split-step", "Sprint all the way in", answerIndex: 0)
        ),
        Flashcard(
            id: "ts-shoetops",
            frontTitle: "The ball at your shoetops",
            frontSubtitle: "You are mid-transition and it lands at your feet.",
            backTitle: "Reset, never drive",
            backBody: "From below your knees, moving forward, there is no shot with offense in it. The reset takes the pace off and drops it in their kitchen so the next ball comes back up and you get to keep walking. Driving from here sends a rising ball to two players at the line; it is the most common way a team loses a rally they had already half-rescued.",
            principle: Principle.reset.tag
        ),
    ]

    static let thirdShotQuiz: [QuizQuestion] = [
        QuizQuestion(
            id: "ts-q-both-set",
            prompt: "You are serving. The return was deep, you are behind your baseline, and both opponents are established at the kitchen line. The ball is at knee height.",
            givens: [.ballHeight(.belowNet), .you(.baseline), .opponents("Both at the line")],
            choices: [
                "Third shot drop into the kitchen",
                "Drive hard down the line",
                "Drive at the middle",
                "Lob deep cross-court",
            ],
            answerIndex: 0,
            explanation: "Nobody is out of position and the ball is below the net, so there is nothing to attack and no one to attack. The drop is the only shot that lands unattackable and buys you the time to walk in, which is the entire job of a third shot.",
            principle: Principle.getToTheLine.tag
        ),
        QuizQuestion(
            id: "ts-q-one-back",
            prompt: "You are hitting a third. Their left player is at the kitchen line; their right player is still four feet behind it, walking in. The ball is at waist height.",
            givens: [.ballHeight(.netHeight), .opponents("Left at the line, right still walking in")],
            choices: [
                "Drive at the right opponent's feet",
                "Drop cross-court into the kitchen",
                "Drop straight into the kitchen",
                "Lob over the left opponent",
            ],
            answerIndex: 0,
            explanation: "One opponent has not made the line, which is exactly the condition a drive is for. A ball driven at the feet of someone still moving forces a half-volley from an unset position. Dropping here is not a disaster, it just declines a free advantage.",
            principle: Principle.hitWhoIsntSet.tag
        ),
        QuizQuestion(
            id: "ts-q-high-third",
            prompt: "The return floats short and you get to take your third shot above the height of the net, from just inside the baseline.",
            givens: [.ballHeight(.aboveNet), .opponents("Both at the line")],
            choices: [
                "Drive it, even though they are both set",
                "Drop it, because they are both set",
                "Lob it deep",
                "Dink it into the kitchen",
            ],
            answerIndex: 0,
            explanation: "Height overrides the usual rule. Above the net you hit through the ball rather than lifting it, so it arrives flat and fast rather than rising into their paddles. A short return is a mistake, and a drop would hand it straight back.",
            principle: Principle.finishDown.tag
        ),
        QuizQuestion(
            id: "ts-q-middle-third",
            prompt: "You are taking a third shot from close to the centre line. Both opponents are set at the kitchen line in normal position. The ball is low.",
            givens: [.ballHeight(.belowNet), .side("Near the centre line"), .opponents("Both at the line")],
            choices: [
                "Drop straight into the kitchen in front of you",
                "Drop sharply cross-court",
                "Drive at the middle seam",
                "Lob the cross-court opponent",
            ],
            answerIndex: 0,
            explanation: "From the middle both balls travel about the same distance, so the cross-court drop loses the margin that normally makes it the default and asks you to manufacture an angle. The straight drop is shorter, simpler, and just as unattackable.",
            principle: Principle.longestDiagonal.tag
        ),
        QuizQuestion(
            id: "ts-q-transition-reset",
            prompt: "You dropped, moved in, and got caught halfway. Their fourth shot arrives at your shoetops with pace while you are still moving forward.",
            givens: [.ballHeight(.belowNet), .you(.transition), .opponents("Both at the line")],
            choices: [
                "Reset it softly into their kitchen",
                "Counter-drive it back at them",
                "Lob it to buy time",
                "Take a big cut at the middle",
            ],
            answerIndex: 0,
            explanation: "There is no offense from below your knees while your weight is moving. The reset absorbs the pace and lands soft, so the next ball has to come back up and you get to finish the walk in. Countering from here sends a rising ball into two ready paddles.",
            principle: Principle.reset.tag
        ),
        QuizQuestion(
            id: "ts-q-partner-back",
            prompt: "You are at the kitchen line but your partner is still stuck at the baseline after a poor drop. The ball comes to you low.",
            givens: [.ballHeight(.belowNet), .you(.kitchen), .partner(.baseline)],
            choices: [
                "Dink it and give your partner time to come in",
                "Speed it up to end the rally quickly",
                "Lob it so you both can reset",
                "Drive it at the nearest opponent",
            ],
            answerIndex: 0,
            explanation: "A team split front-to-back is vulnerable through the middle and behind the up player. The soft ball keeps the rally neutral and gives your partner the seconds to join you. Speeding up from a low ball while your partner is out of position is how a bad drop becomes a lost point.",
            principle: Principle.patience.tag
        ),
    ]

    /// Six positions, read step by step.
    ///
    /// The positions, options and answers come from pinned generator seeds
    /// rather than hand-built coordinates. That is deliberate and it is the
    /// only safe way to author this room: a hand-written position can drift
    /// out of agreement with `ShotAdvisor`, and a worked example that teaches
    /// a different answer than the app grades is worse than no worked example.
    /// The authored part is the part that should be authored: the situation
    /// line, and the order of the read.
    static let workedReads: [WorkedRead] = [
        curated(
            id: "wr-third-both-set",
            phase: .thirdShot,
            seed: 8_100_034,
            situation: "A textbook third: the return was deep, nobody is out of position, and the temptation is to try to hit your way out of it.",
            steps: [
                "Height first. The ball is below the net, so no shot you hit here can travel downward. That removes the drive before you even look up.",
                "Your feet. You are back near the baseline, which means the shot has to buy you the fifteen feet to the line.",
                "Their feet. Both opponents are established at the kitchen. There is no unset player to punish and no seam worth aiming at.",
                "So the shot is the one that lands unattackable and gives you time: the drop.",
            ]
        ),
        curated(
            id: "wr-third-one-lagging",
            phase: .thirdShot,
            seed: 8_100_112,
            situation: "The same phase, one difference: somebody has not made the line yet. That difference is worth the whole point.",
            steps: [
                "Height first. Check it before anything else, because it decides whether a hard ball is even available.",
                "Their feet. One opponent is still short of the kitchen line. That is the read the entire phase is built on.",
                "A ball at the feet of a player who is still moving forces a half-volley from a position they have not set up in.",
                "So the answer targets that player rather than taking the safe drop.",
            ]
        ),
        curated(
            id: "wr-dink-seam",
            phase: .dinkRally,
            seed: 8_200_057,
            situation: "A long kitchen exchange. Nothing is high, but the last few balls have moved them.",
            steps: [
                "Height first. Below the net, so nothing gets attacked here by anyone.",
                "Your feet. You are at the line and stable, so you have every soft option available.",
                "Their feet. Look at the gap between the two markers rather than at either one of them.",
                "The seam or the diagonal follows directly from that gap, and the answer names which.",
            ]
        ),
        curated(
            id: "wr-attack-high",
            phase: .attack,
            seed: 8_300_021,
            situation: "The ball you have been waiting eleven dinks for. Most players still get the target wrong.",
            steps: [
                "Height first. Above the net, which means for the first time in this rally you can hit downward.",
                "Your feet. You are at the line, so you are close enough for a downward ball to stay down.",
                "Their feet. The target is a body or a seam, never a sideline: you already have the angle, so you do not need the extra risk.",
                "So the answer finishes down, at the place their paddles cannot get to.",
            ]
        ),
        curated(
            id: "wr-defense-shoetops",
            phase: .defense,
            seed: 8_400_090,
            situation: "You are under pressure and the instinct to swing back at it is exactly wrong.",
            steps: [
                "Height first. The ball is low and coming at you, so there is no offense in this position at all.",
                "Your feet. You are not at the line, which means a hard ball leaves you nowhere to recover to.",
                "Their feet. Both opponents are up and ready, so anything rising arrives at two waiting paddles.",
                "So the answer takes the pace off and lands it soft. Survive the ball, take the next one from better ground.",
            ]
        ),
        curated(
            id: "wr-return-deep",
            phase: .serveReturn,
            seed: 8_500_015,
            situation: "The shot most improving players treat as an afterthought, and the one that decides who owns the line.",
            steps: [
                "Height first. Even a serve that sits up does not change what this shot is for.",
                "Your feet. You are back, and the two-bounce rule means you have time to walk in behind this ball.",
                "Their feet. Both opponents are pinned at their baseline until the return bounces.",
                "So the answer is depth, not pace. Deep keeps them back; pace would only shorten the time you were trying to buy.",
            ]
        ),
    ]

    /// Builds a worked read from a pinned generator seed, so the position, the
    /// options and the graded answer are the generator's and cannot disagree
    /// with `ShotAdvisor`.
    private static func curated(
        id: String,
        phase: RallyPhase,
        seed: UInt64,
        situation: String,
        steps: [String]
    ) -> WorkedRead {
        let question = PositionGenerator.question(phase: phase, seed: seed)
        var steps = steps
        steps.append("So: \(question.answer.label).")
        return WorkedRead(
            id: id,
            situation: situation,
            position: question.position,
            choices: question.options.map(\.label),
            answerIndex: question.answerIndex,
            steps: steps,
            principle: question.verdict.principle,
            mistakes: MistakeCatalog.mistakes(for: question)
        )
    }
}
