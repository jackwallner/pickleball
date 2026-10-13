import Foundation

/// A generated drill: the position, the four options shown, and the answer.
///
/// `answerIndex` is resolved once, at construction, and the initialiser refuses
/// to build a question whose options do not contain the advisor's answer. The
/// paid coaching contract is that every graded ball is graded against the
/// advisor; silently falling back to option zero would keep the app running
/// while quietly marking the wrong shot correct, which is the one failure mode
/// worth crashing a debug build over.
struct DrillQuestion: Identifiable, Sendable {
    let position: RallyPosition
    let options: [Shot]
    let verdict: ShotVerdict
    let answerIndex: Int

    var id: String { position.id }

    init(position: RallyPosition, options: [Shot], verdict: ShotVerdict) {
        self.position = position
        self.options = options
        self.verdict = verdict
        guard let index = options.firstIndex(of: verdict.best) else {
            preconditionFailure(
                "\(position.id): options \(options.map(\.id)) do not contain "
                + "the advisor's answer \(verdict.best.id)"
            )
        }
        self.answerIndex = index
    }

    var answer: Shot { options[answerIndex] }
}

/// Deterministic, seedable RNG so a drill can be replayed exactly. The system
/// generator is not reproducible, and a position you cannot reproduce is a
/// position you cannot file a bug against.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        // Avoid the zero state, which splitmix64 maps to a fixed point.
        state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

/// Builds valid court situations for a phase.
///
/// The generator's contract, pinned by `PositionGeneratorTests`: every position
/// it emits is physically legal (everyone on the court, on the right side of
/// the net), matches the phase it was asked for, and produces an option list
/// that contains the advisor's answer exactly once. That contract is what lets
/// the paid tier promise practice that never runs out.
enum PositionGenerator {

    static func question(phase: RallyPhase, seed: UInt64) -> DrillQuestion {
        var rng = SeededGenerator(seed: seed)
        let position = position(phase: phase, seed: seed, rng: &rng)
        let verdict = ShotAdvisor.verdict(for: position)
        let options = options(for: position, answer: verdict.best, rng: &rng)
        return DrillQuestion(position: position, options: options, verdict: verdict)
    }

    /// A mixed session across every phase, which is what a real rally feels
    /// like and what stops a player pattern-matching on the court title.
    static func session(count: Int, seed: UInt64) -> [DrillQuestion] {
        var rng = SeededGenerator(seed: seed)
        return (0..<count).map { index in
            let phase = RallyPhase.allCases.randomElement(using: &rng) ?? .dinkRally
            return question(phase: phase, seed: seed &+ UInt64(index &* 7919))
        }
    }

    // MARK: - Positions

    private static func position(
        phase: RallyPhase, seed: UInt64, rng: inout SeededGenerator
    ) -> RallyPosition {
        // Half of every phase is reflected across the center line. Without it
        // the "one opponent is lagging" scenarios below are always the right
        // hand player, and the drill trains a side instead of a read.
        let mirror = Bool.random(using: &rng)
        let raw = rawPosition(phase: phase, seed: seed, rng: &rng)
        return mirror ? raw.mirrored : raw
    }

    private static func rawPosition(
        phase: RallyPhase, seed: UInt64, rng: inout SeededGenerator
    ) -> RallyPosition {
        let id = "\(phase.rawValue)-\(seed)"
        let yourScore = Int.random(in: 0...10, using: &rng)
        let theirScore = Int.random(in: 0...10, using: &rng)

        switch phase {
        case .serveReturn:
            // You are back returning serve; your partner is already at the line.
            let you = point(x: lateral(&rng), y: .random(in: 1...5, using: &rng))
            return RallyPosition(
                id: id, phase: phase,
                you: you,
                partner: partnerPoint(across: you, y: 13.7...14.9, &rng),
                opponentLeft: farPoint(&rng, x: opponentLeftX, y: 38...43),
                opponentRight: farPoint(&rng, x: opponentRightX, y: 38...43),
                contact: contactPoint(from: you, &rng),
                ballHeight: [.netHeight, .aboveNet].randomElement(using: &rng)!,
                yourScore: yourScore, theirScore: theirScore, isServingTeam: false
            )

        case .thirdShot:
            // Serving team's third. Sometimes one opponent has not made the line.
            let bothUp = Bool.random(using: &rng)
            let leftUp = bothUp || Bool.random(using: &rng)
            let you = point(x: lateral(&rng), y: .random(in: 1...6, using: &rng))
            return RallyPosition(
                id: id, phase: phase,
                you: you,
                partner: partnerPoint(across: you, y: 1...6, &rng),
                opponentLeft: leftUp ? farPoint(&rng, x: opponentLeftX, y: 29...30.2)
                                     : farPoint(&rng, x: opponentLeftX, y: 33...39),
                opponentRight: (bothUp || !leftUp) ? farPoint(&rng, x: opponentRightX, y: 29...30.2)
                                                   : farPoint(&rng, x: opponentRightX, y: 33...39),
                contact: contactPoint(from: you, &rng),
                ballHeight: bothUp
                    ? [.belowNet, .belowNet, .aboveNet].randomElement(using: &rng)!
                    : .belowNet,
                yourScore: yourScore, theirScore: theirScore, isServingTeam: true
            )

        case .transition:
            let you = point(x: lateral(&rng), y: .random(in: 9...13.5, using: &rng))
            return RallyPosition(
                id: id, phase: phase,
                you: you,
                partner: partnerPoint(across: you, y: 9...13.5, &rng),
                opponentLeft: farPoint(&rng, x: opponentLeftX, y: 29...30.2),
                opponentRight: farPoint(&rng, x: opponentRightX, y: 29...30.2),
                contact: contactPoint(from: you, &rng, forward: -0.6...0.9),
                ballHeight: [.belowNet, .belowNet, .netHeight, .aboveNet]
                    .randomElement(using: &rng)!,
                yourScore: yourScore, theirScore: theirScore, isServingTeam: Bool.random(using: &rng)
            )

        case .dinkRally:
            // Everyone at the line, ball never above net: that would be an attack.
            let oneLagging = Int.random(in: 0...3, using: &rng) == 0
            let you = kitchenPoint(&rng, side: .near)
            return RallyPosition(
                id: id, phase: phase,
                you: you,
                partner: partnerPoint(across: you, y: 13.7...14.9, &rng),
                opponentLeft: farPoint(&rng, x: opponentLeftX, y: 29...30.2),
                opponentRight: oneLagging ? farPoint(&rng, x: opponentRightX, y: 33...37)
                                          : farPoint(&rng, x: opponentRightX, y: 29...30.2),
                // At the line the ball is taken in front of you, never behind:
                // a dink you let get past your feet is a ball you cannot dink.
                contact: contactPoint(from: you, &rng, reach: 2.2, forward: 0.3...1.6),
                ballHeight: [.belowNet, .belowNet, .netHeight].randomElement(using: &rng)!,
                yourScore: yourScore, theirScore: theirScore, isServingTeam: Bool.random(using: &rng)
            )

        case .attack:
            let oneLagging = Bool.random(using: &rng)
            let you = kitchenPoint(&rng, side: .near)
            return RallyPosition(
                id: id, phase: phase,
                you: you,
                partner: partnerPoint(across: you, y: 13.7...14.9, &rng),
                opponentLeft: farPoint(&rng, x: opponentLeftX, y: 29...30.2),
                opponentRight: oneLagging ? farPoint(&rng, x: opponentRightX, y: 32...36)
                                          : farPoint(&rng, x: opponentRightX, y: 29...30.2),
                contact: contactPoint(from: you, &rng, reach: 2.2, forward: 0.3...1.6),
                ballHeight: .aboveNet,
                yourScore: yourScore, theirScore: theirScore, isServingTeam: Bool.random(using: &rng)
            )

        case .defense:
            let pinnedBack = Bool.random(using: &rng)
            let depth: ClosedRange<Double> = pinnedBack ? 1...6 : 9...13
            let you = point(x: lateral(&rng), y: .random(in: depth, using: &rng))
            return RallyPosition(
                id: id, phase: phase,
                you: you,
                partner: partnerPoint(across: you, y: 4...12, &rng),
                opponentLeft: farPoint(&rng, x: opponentLeftX, y: 29...30.2),
                opponentRight: farPoint(&rng, x: opponentRightX, y: 29...30.2),
                // Under pressure the ball is on you, not out in front: a
                // defensive contact is late and low by definition.
                contact: contactPoint(from: you, &rng, forward: -1.0...0.8),
                ballHeight: pinnedBack ? [.belowNet, .netHeight].randomElement(using: &rng)!
                                       : .belowNet,
                yourScore: yourScore, theirScore: theirScore, isServingTeam: Bool.random(using: &rng)
            )
        }
    }

    // MARK: - Options

    /// Four options: the answer plus three plausible distractors. Distractors
    /// are drawn from the shots a real player is actually tempted by in that
    /// phase, never from a random pool, because an obviously-wrong option
    /// makes the drill free.
    private static func options(
        for position: RallyPosition, answer: Shot, rng: inout SeededGenerator
    ) -> [Shot] {
        var pool = distractors(for: position).filter { $0 != answer }
        pool = Array(Set(pool)).sorted { $0.id < $1.id }
        pool.shuffle(using: &rng)
        var chosen = Array(pool.prefix(3))
        // Backstop: never show fewer than four options, even if a phase's
        // distractor list collides heavily with the answer.
        for fallback in Self.universalFallbacks where chosen.count < 3 {
            if fallback != answer && !chosen.contains(fallback) { chosen.append(fallback) }
        }
        var result = chosen + [answer]
        result.shuffle(using: &rng)
        return result
    }

    private static let universalFallbacks: [Shot] = [
        Shot(.dink, .crossCourtKitchen),
        Shot(.drive, .deepStraight),
        Shot(.lob, .deepCrossCourt),
        Shot(.reset, .straightKitchen),
    ]

    private static func distractors(for position: RallyPosition) -> [Shot] {
        switch position.phase {
        case .serveReturn:
            return [Shot(.drive, .deepStraight), Shot(.drop, .crossCourtKitchen),
                    Shot(.lob, .deepCrossCourt), Shot(.deepReturn, .middle),
                    Shot(.drive, .backhand)]
        case .thirdShot:
            return [Shot(.drop, .crossCourtKitchen), Shot(.drive, .atFeet),
                    Shot(.drive, .backhand), Shot(.lob, .deepCrossCourt),
                    Shot(.drop, .straightKitchen), Shot(.reset, .straightKitchen)]
        case .transition:
            return [Shot(.reset, .straightKitchen), Shot(.drive, .atFeet),
                    Shot(.drive, .deepStraight), Shot(.lob, .deepCrossCourt),
                    Shot(.dink, .crossCourtKitchen)]
        case .dinkRally:
            return [Shot(.dink, .crossCourtKitchen), Shot(.dink, .middle),
                    Shot(.dink, .atFeet), Shot(.speedUp, .backhand),
                    Shot(.lob, .deepCrossCourt)]
        case .attack:
            return [Shot(.putAway, .atFeet), Shot(.drive, .atFeet),
                    Shot(.speedUp, .backhand), Shot(.dink, .crossCourtKitchen),
                    Shot(.lob, .deepCrossCourt)]
        case .defense:
            return [Shot(.reset, .straightKitchen), Shot(.lob, .deepCrossCourt),
                    Shot(.drive, .deepStraight), Shot(.dink, .crossCourtKitchen),
                    Shot(.speedUp, .backhand)]
        }
    }

    // MARK: - Point helpers

    /// The two opponents' lateral bands.
    ///
    /// Deliberately separated. The old bands (3...9 and 11...17) could put both
    /// opponents two feet apart in the middle of the court, which no doubles
    /// team has ever done and which rendered, in first person, as two people
    /// standing on each other. Five to fifteen feet apart is the real range,
    /// and it still spans both sides of `CourtGeometry.openMiddleGap`, so the
    /// "they have left the seam open" read is generated as often as before.
    private static let opponentLeftX: ClosedRange<Double> = 2.5...7.5
    private static let opponentRightX: ClosedRange<Double> = 12.5...17.5

    private static func lateral(_ rng: inout SeededGenerator) -> Double {
        .random(in: 1.5...(CourtGeometry.width - 1.5), using: &rng)
    }

    private static func point(x: Double, y: Double) -> CourtPoint {
        CourtGeometry.clamp(CourtPoint(x: x, y: y))
    }

    /// Where you make contact, derived from where you are STANDING.
    ///
    /// This used to be an independent draw, and it was the one generator bug
    /// the overhead diagram was hiding. Two separate rolls routinely put the
    /// ball eight feet to the side of the feet that were supposed to be
    /// hitting it: in plan view that is two dots near each other, and in first
    /// person it is a ball fifty degrees off your nose that no human could
    /// reach. A contact is a REACH from a stance, so it is generated as one.
    ///
    /// `forward` is signed because where the ball is relative to your body is
    /// itself part of the phase: at the kitchen you take it in front, on
    /// defense it has already got in on you.
    private static func contactPoint(
        from you: CourtPoint,
        _ rng: inout SeededGenerator,
        reach: Double = 2.6,
        forward: ClosedRange<Double> = -0.6...1.9
    ) -> CourtPoint {
        let across = Double.random(in: -reach...reach, using: &rng)
        let ahead = Double.random(in: forward, using: &rng)
        return point(
            x: you.x + across,
            // Never on or past the net: you cannot make contact over the tape.
            y: min(you.y + ahead, CourtGeometry.netY - 1.0)
        )
    }

    /// Your partner, on the other half of the court from you.
    ///
    /// Also an independent draw before, which put two team-mates on the same
    /// square foot often enough to see it, and which in first person renders as
    /// a body standing inside your own head. Doubles partners cover a side
    /// each, so the partner is placed across the center line from you and the
    /// depth band stays the one the phase asked for.
    private static func partnerPoint(
        across you: CourtPoint, y: ClosedRange<Double>, _ rng: inout SeededGenerator
    ) -> CourtPoint {
        let x: Double = you.x < CourtGeometry.centerX
            ? .random(in: (CourtGeometry.centerX + 0.5)...(CourtGeometry.width - 1.5), using: &rng)
            : .random(in: 1.5...(CourtGeometry.centerX - 0.5), using: &rng)
        return point(x: x, y: .random(in: y, using: &rng))
    }

    private static func kitchenPoint(
        _ rng: inout SeededGenerator, side: CourtSide
    ) -> CourtPoint {
        let y: Double = side == .near
            ? .random(in: 13.7...14.9, using: &rng)
            : .random(in: 29.1...30.2, using: &rng)
        return point(x: lateral(&rng), y: y)
    }

    private static func farPoint(
        _ rng: inout SeededGenerator, x: ClosedRange<Double>, y: ClosedRange<Double>
    ) -> CourtPoint {
        point(x: .random(in: x, using: &rng), y: .random(in: y, using: &rng))
    }
}
