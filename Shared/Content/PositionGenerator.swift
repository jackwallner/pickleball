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
            return RallyPosition(
                id: id, phase: phase,
                you: point(x: lateral(&rng), y: .random(in: 1...5, using: &rng)),
                partner: kitchenPoint(&rng, side: .near),
                opponentLeft: farPoint(&rng, x: 3...9, y: 38...43),
                opponentRight: farPoint(&rng, x: 11...17, y: 38...43),
                contact: point(x: lateral(&rng), y: .random(in: 1...5, using: &rng)),
                ballHeight: [.netHeight, .aboveNet].randomElement(using: &rng)!,
                yourScore: yourScore, theirScore: theirScore, isServingTeam: false
            )

        case .thirdShot:
            // Serving team's third. Sometimes one opponent has not made the line.
            let bothUp = Bool.random(using: &rng)
            let leftUp = bothUp || Bool.random(using: &rng)
            return RallyPosition(
                id: id, phase: phase,
                you: point(x: lateral(&rng), y: .random(in: 1...6, using: &rng)),
                partner: point(x: lateral(&rng), y: .random(in: 1...6, using: &rng)),
                opponentLeft: leftUp ? farPoint(&rng, x: 3...9, y: 29...30.2)
                                     : farPoint(&rng, x: 3...9, y: 33...39),
                opponentRight: (bothUp || !leftUp) ? farPoint(&rng, x: 11...17, y: 29...30.2)
                                                   : farPoint(&rng, x: 11...17, y: 33...39),
                contact: point(x: lateral(&rng), y: .random(in: 1...6, using: &rng)),
                ballHeight: bothUp
                    ? [.belowNet, .belowNet, .aboveNet].randomElement(using: &rng)!
                    : .belowNet,
                yourScore: yourScore, theirScore: theirScore, isServingTeam: true
            )

        case .transition:
            return RallyPosition(
                id: id, phase: phase,
                you: point(x: lateral(&rng), y: .random(in: 9...13.5, using: &rng)),
                partner: point(x: lateral(&rng), y: .random(in: 9...13.5, using: &rng)),
                opponentLeft: farPoint(&rng, x: 3...9, y: 29...30.2),
                opponentRight: farPoint(&rng, x: 11...17, y: 29...30.2),
                contact: point(x: lateral(&rng), y: .random(in: 9...13.5, using: &rng)),
                ballHeight: [.belowNet, .belowNet, .netHeight, .aboveNet]
                    .randomElement(using: &rng)!,
                yourScore: yourScore, theirScore: theirScore, isServingTeam: Bool.random(using: &rng)
            )

        case .dinkRally:
            // Everyone at the line, ball never above net: that would be an attack.
            let oneLagging = Int.random(in: 0...3, using: &rng) == 0
            return RallyPosition(
                id: id, phase: phase,
                you: kitchenPoint(&rng, side: .near),
                partner: kitchenPoint(&rng, side: .near),
                opponentLeft: farPoint(&rng, x: 3...9, y: 29...30.2),
                opponentRight: oneLagging ? farPoint(&rng, x: 11...17, y: 33...37)
                                          : farPoint(&rng, x: 11...17, y: 29...30.2),
                contact: kitchenPoint(&rng, side: .near),
                ballHeight: [.belowNet, .belowNet, .netHeight].randomElement(using: &rng)!,
                yourScore: yourScore, theirScore: theirScore, isServingTeam: Bool.random(using: &rng)
            )

        case .attack:
            let oneLagging = Bool.random(using: &rng)
            return RallyPosition(
                id: id, phase: phase,
                you: kitchenPoint(&rng, side: .near),
                partner: kitchenPoint(&rng, side: .near),
                opponentLeft: farPoint(&rng, x: 3...9, y: 29...30.2),
                opponentRight: oneLagging ? farPoint(&rng, x: 11...17, y: 32...36)
                                          : farPoint(&rng, x: 11...17, y: 29...30.2),
                contact: kitchenPoint(&rng, side: .near),
                ballHeight: .aboveNet,
                yourScore: yourScore, theirScore: theirScore, isServingTeam: Bool.random(using: &rng)
            )

        case .defense:
            let pinnedBack = Bool.random(using: &rng)
            return RallyPosition(
                id: id, phase: phase,
                you: point(x: lateral(&rng),
                           y: pinnedBack ? .random(in: 1...6, using: &rng)
                                         : .random(in: 9...13, using: &rng)),
                partner: point(x: lateral(&rng), y: .random(in: 4...12, using: &rng)),
                opponentLeft: farPoint(&rng, x: 3...9, y: 29...30.2),
                opponentRight: farPoint(&rng, x: 11...17, y: 29...30.2),
                contact: point(x: lateral(&rng),
                               y: pinnedBack ? .random(in: 1...6, using: &rng)
                                             : .random(in: 9...13, using: &rng)),
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

    private static func lateral(_ rng: inout SeededGenerator) -> Double {
        .random(in: 1.5...(CourtGeometry.width - 1.5), using: &rng)
    }

    private static func point(x: Double, y: Double) -> CourtPoint {
        CourtGeometry.clamp(CourtPoint(x: x, y: y))
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
