import Foundation

/// What a focus point is aimed at: a phase, and optionally the named trap the
/// generated position must contain as one of its options.
struct RallyFocus: Equatable, Sendable {
    let phase: RallyPhase
    let mistakeID: String?
    /// Picked from the player's level rather than from their own misses, so
    /// it is not labelled as something they need to fix.
    var isStarter: Bool = false
}

/// One decision inside a point.
struct RallyBall: Identifiable, Sendable {
    let question: DrillQuestion
    /// Which point of the run this belongs to.
    let pointIndex: Int
    /// Which decision this is inside that point, from zero.
    let shotIndex: Int
    /// The number of decisions the point holds in total.
    let shotsInPoint: Int
    /// Set when this ball was generated to test one of the player's weak spots.
    var focus: RallyFocus? = nil

    var id: String { "\(pointIndex)-\(shotIndex)-\(question.id)" }
    var isLastOfPoint: Bool { shotIndex == shotsInPoint - 1 }
    var position: RallyPosition { question.position }
}

/// Builds points, not flashcards.
///
/// A point is an ordered run of YOUR decisions: return or third, the walk in,
/// the kitchen, and the finish. Getting one right advances the rally; getting
/// one wrong ends the point. Every third point is a focus point, a single ball
/// generated to test the trap or phase that has been costing this player the
/// most, so the court leans into their weak spots without announcing a drill.
enum RallyBuilder {

    /// Every `focusEvery`th point is a focus point when there is a focus.
    static let focusEvery = 3

    /// The decisions you actually face in a point, depending on which team you
    /// are on. On the returning team you never hit a third shot; on the
    /// serving team you never hit a return.
    static func script(servingTeam: Bool, rng: inout SeededGenerator) -> [RallyPhase] {
        if servingTeam {
            var phases: [RallyPhase] = [.thirdShot, .transition, .dinkRally]
            phases.append([RallyPhase.attack, .defense].randomElement(using: &rng) ?? .attack)
            return phases
        }
        var phases: [RallyPhase] = [.serveReturn]
        phases.append([RallyPhase.defense, .dinkRally].randomElement(using: &rng) ?? .dinkRally)
        phases.append(.dinkRally)
        phases.append([RallyPhase.attack, .defense].randomElement(using: &rng) ?? .attack)
        return phases
    }

    /// A run of points, flattened into the balls that make them up.
    ///
    /// `ballBudget` is the free tier's remaining allowance, so the last point
    /// is truncated rather than promised and then cut off.
    static func session(
        ballBudget: Int,
        seed: UInt64,
        focus: [RallyFocus] = [],
        half: CourtHalf = .either
    ) -> [RallyBall] {
        guard ballBudget > 0 else { return [] }
        var rng = SeededGenerator(seed: seed)
        var balls: [RallyBall] = []
        var pointIndex = 0
        var focusIndex = 0

        while balls.count < ballBudget {
            if !focus.isEmpty, pointIndex % focusEvery == focusEvery - 1 {
                let target = focus[focusIndex % focus.count]
                focusIndex += 1
                let question = focusQuestion(
                    target, seed: seed &+ UInt64(pointIndex &* 7_919), half: half
                )
                // Rejection sampling can miss; then the ball tests the phase,
                // and must not claim to test a trap it does not offer.
                let offered = target.mistakeID.map { id in
                    MistakeCatalog.mistakes(for: question).values.contains { $0.id == id }
                } ?? true
                balls.append(RallyBall(
                    question: question, pointIndex: pointIndex,
                    shotIndex: 0, shotsInPoint: 1,
                    focus: offered ? target : RallyFocus(phase: target.phase, mistakeID: nil, isStarter: target.isStarter)
                ))
                pointIndex += 1
                continue
            }

            let phases = script(servingTeam: Bool.random(using: &rng), rng: &rng)
            let taken = Array(phases.prefix(ballBudget - balls.count))
            for (shotIndex, phase) in taken.enumerated() {
                let question = PositionGenerator.question(
                    phase: phase,
                    seed: seed &+ UInt64((pointIndex &* 1_000 &+ shotIndex) &* 104_729)
                )
                balls.append(RallyBall(
                    question: oriented(question, half: half),
                    pointIndex: pointIndex,
                    shotIndex: shotIndex,
                    // Keep the original script length. If the allowance ends
                    // halfway through this point, the final stored ball must
                    // not pretend it completed the rally and award a point.
                    shotsInPoint: phases.count
                ))
            }
            pointIndex += 1
        }
        return balls
    }

    /// A position of the focus phase that offers the named trap as an option.
    ///
    /// Bounded rejection sampling: a phase whose trap does not apply to the
    /// position it rolls falls back to an untargeted position of that phase.
    static func focusQuestion(_ focus: RallyFocus, seed: UInt64, half: CourtHalf = .either) -> DrillQuestion {
        for attempt in 0..<32 {
            let candidate = oriented(
                PositionGenerator.question(phase: focus.phase, seed: seed &+ UInt64(attempt &* 31)),
                half: half
            )
            guard let id = focus.mistakeID else { return candidate }
            if MistakeCatalog.mistakes(for: candidate).values.contains(where: { $0.id == id }) {
                return candidate
            }
        }
        return oriented(PositionGenerator.question(phase: focus.phase, seed: seed), half: half)
    }

    /// Mirrors a question so the player stands on the half they chose. The
    /// advisor is mirror-symmetric (pinned by `ShotAdvisorTests`), so the same
    /// four shots stay valid and the answer is re-derived, not assumed.
    static func oriented(_ question: DrillQuestion, half: CourtHalf) -> DrillQuestion {
        let onLeft = question.position.you.isLeftHalf
        switch half {
        case .either: return question
        case .left where onLeft, .right where !onLeft: return question
        default:
            let mirrored = question.position.mirrored
            return DrillQuestion(
                position: mirrored,
                options: question.options,
                verdict: ShotAdvisor.verdict(for: mirrored)
            )
        }
    }

    /// The index of the first ball of the point after `pointIndex`, or nil when
    /// the run is over. Losing a point skips the rest of it.
    static func firstBall(after pointIndex: Int, in balls: [RallyBall]) -> Int? {
        balls.firstIndex { $0.pointIndex > pointIndex }
    }
}
