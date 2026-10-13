import Foundation

/// One normalized, single-select item inside a Quick Session. Built from
/// whichever choice-gradeable content is behind it (quiz, principle-match, a
/// flashcard with a CardChoice, or a position straight off the generator) so
/// the session itself never has to know the source shape.
struct QuickItem: Identifiable, Sendable {
    let id: String
    let prompt: String
    let givens: [Given]
    /// The court behind this question, when there is one.
    ///
    /// This is the seam the whole port hangs on. An authored question carries
    /// `givens` and no position; a generated one carries a position and no
    /// givens; the runner renders whichever it finds and grades both the same
    /// way. Without it the generator would have to flatten four sets of feet
    /// into prose, which is exactly the thing the diagram exists to avoid.
    let position: RallyPosition?
    /// The marker the graded answer is aimed at, revealed after the pick.
    /// Naming a target is only coaching if the player can see which of the two
    /// identical markers it means.
    let targetOpponent: OpponentSide?
    /// The four options as SHOTS rather than as strings, when this item came
    /// from the generator.
    ///
    /// A shot knows where it lands, and a string does not. This is what lets a
    /// generated question inside one of the shell's session runners be played
    /// the same way it is played from the lobby: on the court, by aiming.
    /// Authored items leave it empty and keep their text choices, because a
    /// rules quiz genuinely is a question about words.
    let shots: [Shot]
    let choices: [String]
    let answerIndex: Int
    let explanation: String
    /// The read, one line per step, in order. Empty for items that are not
    /// worked reads. Kept as a list rather than flattened into `explanation`
    /// because a paragraph hides WHICH step was skipped, and a skipped step is
    /// how almost every position is actually misread.
    let steps: [String]
    /// The principle to file the answer under, rendered beneath the working.
    let principle: String?
    /// e.g. "The Kitchen Game", shown as a small tag above the prompt.
    let sourceLabel: String
    /// The court this item came from, for per-court accuracy stats. Generated
    /// items report the court whose phase they drill.
    let courtID: String
    /// The rally phase this item trains, when it maps onto one. Generated items
    /// always do; authored ones do when they are about a specific phase. This
    /// is what keeps the shell's stats and the bespoke `ProgressStore` phase
    /// accuracy talking about the same thing.
    let phase: RallyPhase?
    /// The persistence row this answer contributes to. Most authored items use
    /// their own id. Generated items share one bounded rollup row per phase.
    let trackingID: String
    /// False for one-off generated prompts that can never be scheduled back
    /// into Fix My Mistakes as the same question. Their mistake PATTERN still
    /// comes back; see `mistakes`.
    let isReviewable: Bool
    /// Choice label to the named mistake that produces it. A wrong pick that
    /// appears here can be named to the player and tallied for targeted
    /// practice.
    let mistakes: [String: MistakePattern]
    /// The one mistake this newly generated position was minted to remediate.
    /// A normal generated position may contain several tempting distractors,
    /// so only targeted practice is allowed to work a tally back down.
    let targetedMistakeID: String?

    init(
        id: String,
        prompt: String,
        givens: [Given] = [],
        position: RallyPosition? = nil,
        targetOpponent: OpponentSide? = nil,
        shots: [Shot] = [],
        choices: [String],
        answerIndex: Int,
        explanation: String,
        steps: [String] = [],
        principle: String? = nil,
        sourceLabel: String,
        courtID: String,
        phase: RallyPhase? = nil,
        trackingID: String? = nil,
        isReviewable: Bool = true,
        mistakes: [String: MistakePattern] = [:],
        targetedMistakeID: String? = nil
    ) {
        self.id = id
        self.prompt = prompt
        self.givens = givens
        self.position = position
        self.targetOpponent = targetOpponent
        self.shots = shots
        self.choices = choices
        self.answerIndex = answerIndex
        self.explanation = explanation
        self.steps = steps
        self.principle = principle
        self.sourceLabel = sourceLabel
        self.courtID = courtID
        self.phase = phase
        self.trackingID = trackingID ?? id
        self.isReviewable = isReviewable
        self.mistakes = mistakes
        self.targetedMistakeID = targetedMistakeID
    }

    /// The named mistake behind a pick, if this item knows one.
    func mistake(forChoiceAt index: Int) -> MistakePattern? {
        guard choices.indices.contains(index) else { return nil }
        return mistakes[choices[index]]
    }
}

/// Builds the Quick Session: a short run of choice-only items pulled from
/// across the courts, weighted so misses come back first and unseen material
/// beats review. Plain flip flashcards and worked reads are excluded; they
/// aren't right/wrong in one tap and don't belong in a uniform choice flow.
enum SessionBuilder {

    static let sessionDrill = Drill(
        id: "quick-session",
        title: "Quick Session",
        subtitle: "A short mix of what you need next",
        kind: .flashcards([])
    )

    static let reviewDrill = Drill(
        id: "review-session",
        title: "Fix My Mistakes",
        subtitle: "The reads you keep getting wrong",
        kind: .flashcards([])
    )

    static let matchWarmUpDrill = Drill(
        id: "match-warm-up",
        title: "Match Warm-Up",
        subtitle: "A short targeted mix before you play",
        kind: .flashcards([])
    )

    static func quickSession(
        count: Int = 10,
        seen: Set<String>,
        missed: Set<String>,
        includePro: Bool
    ) -> [QuickItem] {
        let pool = choicePool(includePro: includePro)

        // Priority tiers: missed first, unseen next, review last.
        func tier(_ item: QuickItem) -> Int {
            if missed.contains(item.id) { return 0 }
            if !seen.contains(item.id) { return 1 }
            return 2
        }
        let picked = Dictionary(grouping: pool.shuffled(), by: tier)
            .sorted { $0.key < $1.key }
            .flatMap(\.value)
            .prefix(count)

        return picked.map(prepared)
    }

    /// The Fix My Mistakes session: the authored items the scheduler says are
    /// due, in the order it ranked them, then FRESH generated positions in the
    /// phases the player keeps missing.
    ///
    /// The second half is the part a static library cannot do. Replaying a
    /// position someone has already seen tests their memory of the answer; a
    /// newly generated position in the same phase tests the read that produced
    /// the miss, which is the thing actually worth fixing.
    static func reviewSession(
        ids: [String],
        weakPhases: [RallyPhase] = [],
        count: Int = 10,
        seed: UInt64 = UInt64(Date().timeIntervalSince1970),
        includePro: Bool
    ) -> [QuickItem] {
        let pool = Dictionary(choicePool(includePro: includePro).map { ($0.id, $0) }) { first, _ in first }
        let authored = ids.compactMap { pool[$0] }.map(prepared)
        guard authored.count < count, !weakPhases.isEmpty else { return authored }

        let shortfall = count - authored.count
        let generated = (0..<shortfall).map { index -> QuickItem in
            let phase = weakPhases[index % weakPhases.count]
            return EndlessPractice.item(phase: phase, seed: seed &+ UInt64(index &* 31))
        }
        return authored + generated
    }

    /// A member's pre-match session. Due mistakes lead, then the weakest court,
    /// then unseen material. The final tier keeps the session full for a new
    /// player who has not built enough history to personalize yet.
    static func matchWarmUp(
        count: Int = 10,
        seen: Set<String>,
        missed: Set<String>,
        dueIDs: [String],
        weakestCourtID: String?
    ) -> [QuickItem] {
        let due = Set(dueIDs)
        let pool = choicePool(includePro: true)

        func tier(_ item: QuickItem) -> Int {
            if due.contains(item.id) { return 0 }
            if missed.contains(item.id) { return 1 }
            if item.courtID == weakestCourtID { return 2 }
            if !seen.contains(item.id) { return 3 }
            return 4
        }

        return Dictionary(grouping: pool.shuffled(), by: tier)
            .sorted { $0.key < $1.key }
            .flatMap(\.value)
            .prefix(count)
            .map(prepared)
    }

    /// Used by deterministic daily features to draw from a particular court
    /// without exposing locked content to callers that did not request it.
    static func choiceItems(in courtID: String, includePro: Bool) -> [QuickItem] {
        choicePool(includePro: includePro).filter { $0.courtID == courtID }
    }

    /// Answer-position variety: shuffle each item's choices deterministically
    /// by its own id so the order is stable across re-render/undo but not
    /// always the authored slot.
    static func prepared(_ item: QuickItem) -> QuickItem {
        let permutation = ChoiceShuffle.permutation(count: item.choices.count, seed: item.id)
        let shuffledLabels = permutation.map { item.choices[$0] }
        let shuffledAnswerIndex = permutation.firstIndex(of: item.answerIndex) ?? item.answerIndex
        let shuffledShots = item.shots.count == permutation.count
            ? permutation.map { item.shots[$0] }
            : item.shots
        // `mistakes` is keyed by choice LABEL, not by index, so it survives the
        // shuffle untouched. Keying it by index is the bug waiting to happen.
        return QuickItem(
            id: item.id,
            prompt: item.prompt,
            givens: item.givens,
            position: item.position,
            targetOpponent: item.targetOpponent,
            shots: shuffledShots,
            choices: shuffledLabels,
            answerIndex: shuffledAnswerIndex,
            explanation: item.explanation,
            steps: item.steps,
            principle: item.principle,
            sourceLabel: item.sourceLabel,
            courtID: item.courtID,
            phase: item.phase,
            trackingID: item.trackingID,
            isReviewable: item.isReviewable,
            mistakes: item.mistakes,
            targetedMistakeID: item.targetedMistakeID
        )
    }

    /// Every choice-gradeable item a player is entitled to: the free courts'
    /// free drills, plus (for members) the locked extra sets and the paid courts.
    static func choicePool(includePro: Bool) -> [QuickItem] {
        var pool: [QuickItem] = []
        for court in DrillLibrary.courts where court.isFree || includePro {
            for drill in court.drills where !court.isLocked(drill, isMember: includePro) {
                switch drill.kind {
                case .quiz(let questions):
                    pool += questions.map { question in
                        QuickItem(
                            id: question.id,
                            prompt: question.prompt,
                            givens: question.givens,
                            choices: question.choices,
                            answerIndex: question.answerIndex,
                            explanation: question.explanation,
                            principle: question.principle,
                            sourceLabel: court.name,
                            courtID: court.id,
                            phase: DrillLibrary.phase(forCourtID: court.id)
                        )
                    }
                case .principleMatch(let questions):
                    pool += questions.map { question in
                        let labels = question.choices.map(\.shortName)
                        let answerIndex = question.choices.firstIndex(of: question.answer) ?? 0
                        return QuickItem(
                            id: question.id,
                            prompt: question.scenario,
                            choices: labels,
                            answerIndex: answerIndex,
                            explanation: question.explanation,
                            principle: question.answer.tag,
                            sourceLabel: court.name,
                            courtID: court.id,
                            phase: DrillLibrary.phase(forCourtID: court.id)
                        )
                    }
                case .flashcards(let cards):
                    pool += cards.compactMap { card in
                        guard let choice = card.choice else { return nil }
                        var prompt = card.frontTitle
                        if let subtitle = card.frontSubtitle {
                            prompt += "\n\(subtitle)"
                        }
                        return QuickItem(
                            id: card.id,
                            prompt: prompt,
                            givens: card.givens,
                            choices: choice.options,
                            answerIndex: choice.answerIndex,
                            explanation: card.backBody,
                            principle: card.principle,
                            sourceLabel: court.name,
                            courtID: court.id,
                            phase: DrillLibrary.phase(forCourtID: court.id)
                        )
                    }
                case .worked:
                    break // Worked reads need their steps; they get their own runner.
                }
            }
        }
        return pool
    }
}
