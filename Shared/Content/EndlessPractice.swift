import Foundation

/// The generated-practice catalogue. Each rally phase turns `PositionGenerator`
/// into the same `QuickItem` shape the authored drills produce, so the session
/// runner never has to know whether a question was written by hand or generated
/// a second ago.
///
/// This is the answer to the finite-content problem, and in this app it is also
/// the product: an authored set is a pile a player finishes in a weekend, a
/// generator is a machine that keeps going as long as they keep improving.
///
/// The practice "skill" here is just `RallyPhase`. The shell this was ported from needed a
/// separate enum because its generator had five unrelated calculation shapes;
/// pickleball's phases already are the taxonomy, they are already what
/// `ProgressStore` keys accuracy on, and inventing a parallel list would give
/// the app two names for the same six things.
extension RallyPhase {

    var icon: String {
        switch self {
        case .serveReturn: return "arrow.uturn.backward"
        case .thirdShot: return "arrow.up.forward"
        case .transition: return "figure.walk"
        case .dinkRally: return "hand.tap"
        case .attack: return "bolt.fill"
        case .defense: return "shield.lefthalf.filled"
        }
    }

    /// The court this phase practises, for the stats breakdown.
    var courtID: String {
        switch self {
        case .serveReturn: return DrillLibrary.basicsCourtID
        case .dinkRally: return DrillLibrary.kitchenCourtID
        case .thirdShot, .transition: return DrillLibrary.transitionCourtID
        case .attack, .defense: return DrillLibrary.pressureCourtID
        }
    }

    /// Every generated item carries this prefix so `PracticeRecordStore` can
    /// roll an unbounded stream of one-off ids up into one row of stats.
    var itemPrefix: String { "gen-\(rawValue)-" }

    static func phase(forItemID id: String) -> RallyPhase? {
        allCases.first { id.hasPrefix($0.itemPrefix) }
    }
}

enum EndlessPractice {

    /// A finished endless run is still a "drill" for the completion screen.
    static func drill(for phase: RallyPhase) -> Drill {
        Drill(id: "endless-\(phase.rawValue)", title: phase.title, subtitle: phase.subtitle, kind: .quiz([]))
    }

    static let challengeDrill = Drill(
        id: "timed-challenge",
        title: "Timed Challenge",
        subtitle: "Beat the clock",
        kind: .quiz([])
    )

    static let mixedDrill = Drill(
        id: "endless-mixed",
        title: "Mixed Rally",
        subtitle: "Every phase, the way a real point arrives",
        kind: .quiz([])
    )

    static func items(for phase: RallyPhase, count: Int, seed: UInt64? = nil) -> [QuickItem] {
        let base = seed ?? UInt64.random(in: 0..<UInt64.max)
        return (0..<count).map { item(phase: phase, seed: base &+ UInt64($0 &* 7919)) }
    }

    /// A mixed batch across every phase, which is what a real rally feels like
    /// and what stops a player pattern-matching on the court title.
    static func mixedItems(count: Int, seed: UInt64? = nil) -> [QuickItem] {
        let base = seed ?? UInt64.random(in: 0..<UInt64.max)
        return PositionGenerator.session(count: count, seed: base).map { item(from: $0) }
    }

    /// Adapts a generated question into the session runner's shape.
    ///
    /// The read stays a LIST of steps. Flattening it into one paragraph would
    /// throw away the thing the authored Worked Reads court does best: a miss is
    /// almost never a wild guess, it is one skipped step of the read, and a
    /// paragraph hides which one. The generator is the paid tier, so it gets
    /// the better explanation, not the worse one.
    static func item(
        from question: DrillQuestion,
        sourceLabel: String = "Endless Practice"
    ) -> QuickItem {
        let phase = question.position.phase
        let verdict = question.verdict
        return QuickItem(
            id: phase.itemPrefix + question.position.id,
            prompt: prompt(for: question.position),
            position: question.position,
            targetOpponent: verdict.targetOpponent,
            shots: question.options,
            choices: question.options.map(\.label),
            answerIndex: question.answerIndex,
            explanation: verdict.why,
            steps: readSteps(for: question.position, verdict: verdict),
            principle: verdict.principle,
            sourceLabel: sourceLabel,
            courtID: phase.courtID,
            phase: phase,
            // Every generated ball in a phase reports to one row, so an
            // unbounded stream of one-off ids cannot grow the store forever.
            trackingID: phase.itemPrefix + "rollup",
            isReviewable: false,
            mistakes: MistakeCatalog.mistakes(for: question)
        )
    }

    /// One freshly generated position for a phase.
    static func item(phase: RallyPhase, seed: UInt64, sourceLabel: String = "Endless Practice") -> QuickItem {
        item(from: PositionGenerator.question(phase: phase, seed: seed), sourceLabel: sourceLabel)
    }

    /// The question line above the court.
    ///
    /// The score and nothing else. It used to read "the ball is below net
    /// height from the middle", which is the two facts the answer turns on
    /// printed above a render whose entire job is to make the player read them
    /// off the court. That was correct copy for the overhead diagram it was
    /// written for and is a giveaway now that the same item draws a
    /// first-person court in every mode.
    static func prompt(for position: RallyPosition) -> String {
        "\(position.scoreLine). Where do you hit it?"
    }

    /// The read, in the order a coach teaches it: how high, who is set, where
    /// the space is, then the shot. Naming the order is the point; a player who
    /// checks the height last has already committed to a shot.
    static func readSteps(for position: RallyPosition, verdict: ShotVerdict) -> [String] {
        var steps: [String] = []
        steps.append("Height first: the ball is \(position.ballHeight.label.lowercased()), so \(position.ballHeight.isAttackable ? "this one can be hit down on." : "there is nothing to attack here.")")
        steps.append("Your feet: you are \(position.yourZone.label.lowercased()), hitting \(position.contactSideLabel).")
        if let lagging = position.laggingOpponentSide {
            steps.append("Their feet: \(lagging.label) has not made the line yet. That is the one who isn't set.")
        } else if position.isMiddleOpen {
            steps.append("Their feet: both are at the line but they have drifted wide, so the seam between them is open.")
        } else {
            steps.append("Their feet: both are set at the line and the middle is covered.")
        }
        steps.append("So: \(verdict.best.label).")
        return steps
    }

    /// Positions that set the traps this player keeps walking into.
    ///
    /// This is what makes "your misses come back" honest for generated
    /// practice. A generated position is a one-off: its id will never be seen
    /// again, so scheduling the ITEM for review is meaningless. The MISTAKE is
    /// not a one-off. So instead of replaying a position whose answer they now
    /// remember, this mints a new one of the right phase and keeps it only if
    /// the same named trap is actually one of its distractors.
    ///
    /// Rejection is bounded. A phase whose trap does not apply to the position
    /// it happens to roll (a rally with nobody lagging cannot punish ignoring
    /// the player who isn't set) falls back to an untargeted position of the
    /// same phase rather than returning nothing, because a short Fix My
    /// Mistakes session is worse than a slightly less pointed one.
    static func targetedItems(for patterns: [MistakePattern], count: Int, seed: UInt64? = nil) -> [QuickItem] {
        guard !patterns.isEmpty, count > 0 else { return [] }
        let base = seed ?? UInt64.random(in: 0..<UInt64.max)
        var items: [QuickItem] = []

        for index in 0..<count {
            let pattern = patterns[index % patterns.count]
            guard let phase = RallyPhase(rawValue: pattern.phase) else { continue }

            var made: QuickItem?
            for attempt in 0..<24 {
                let candidate = item(
                    phase: phase,
                    seed: base &+ UInt64(index &* 1_000 &+ attempt),
                    sourceLabel: "Targeted Practice"
                )
                guard candidate.mistakes.values.contains(where: { $0.id == pattern.id }) else { continue }
                made = QuickItem(
                    id: candidate.id,
                    prompt: candidate.prompt,
                    givens: candidate.givens,
                    position: candidate.position,
                    targetOpponent: candidate.targetOpponent,
                    shots: candidate.shots,
                    choices: candidate.choices,
                    answerIndex: candidate.answerIndex,
                    explanation: candidate.explanation,
                    steps: candidate.steps,
                    principle: candidate.principle,
                    sourceLabel: candidate.sourceLabel,
                    courtID: candidate.courtID,
                    phase: candidate.phase,
                    trackingID: candidate.trackingID,
                    isReviewable: candidate.isReviewable,
                    mistakes: candidate.mistakes,
                    targetedMistakeID: pattern.id
                )
                break
            }
            items.append(made ?? item(
                phase: phase,
                seed: base &+ UInt64(index &* 1_000 &+ 999),
                sourceLabel: "Targeted Practice"
            ))
        }
        return items
    }
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
        let position = question.position
        var named: [String: MistakePattern] = [:]
        for shot in question.options where shot != question.verdict.best {
            guard let pattern = pattern(for: shot, in: position) else { continue }
            named[shot.label] = pattern
        }
        return named
    }

    static func pattern(for shot: Shot, in position: RallyPosition) -> MistakePattern? {
        let phase = position.phase.rawValue

        // Attacking a ball that cannot be attacked is the single most common
        // error in the sport, and it is checkable from the height alone.
        if !position.ballHeight.isAttackable,
           shot.type == .drive || shot.type == .speedUp || shot.type == .putAway {
            return MistakePattern(
                id: "attacked-a-low-ball",
                phase: phase,
                summary: "You attacked a ball that was not above the net. There was nothing to hit down on, so that ball pops up and the point is theirs."
            )
        }

        // Driving the return is the mistake the serve-return phase exists to
        // train out: it wins nothing and it keeps you pinned at the baseline.
        if position.phase == .serveReturn, shot.type == .drive {
            return MistakePattern(
                id: "drove-the-return",
                phase: phase,
                summary: "You drove the return. A hard return keeps you at the baseline, which hands the serving team the kitchen line you were trying to take."
            )
        }

        // A shot at the player who IS set, when the other one is still moving.
        if let lagging = position.laggingOpponentSide,
           let aimed = aimedOpponent(for: shot, in: position),
           aimed == lagging.opposite {
            return MistakePattern(
                id: "hit-the-player-who-was-set",
                phase: phase,
                summary: "You hit at the opponent who was already set. \(lagging.label.capitalizedFirst) had not made the line, and that is the one who cannot handle a ball at their feet."
            )
        }

        // Ignoring an open seam in favour of a body.
        if position.isMiddleOpen, shot.target != .middle, shot.type == .dink || shot.type == .drive {
            return MistakePattern(
                id: "ignored-the-open-middle",
                phase: phase,
                summary: "You went at a body with the middle wide open. A ball in the seam is a ball neither player owns, and it is the safest place on the court to put it."
            )
        }

        // Counter-driving from the transition zone instead of resetting.
        if position.phase == .transition || position.phase == .defense,
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
                summary: "You lobbed opponents who were not crowding the line. A lob only works over a team that has nowhere to retreat to."
            )
        }

        return nil
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
