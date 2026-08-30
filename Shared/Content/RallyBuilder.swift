import Foundation

/// One decision inside a point.
struct RallyBall: Identifiable, Sendable {
    let question: DrillQuestion
    /// Which point of the session this belongs to.
    let pointIndex: Int
    /// Which decision this is inside that point, from zero.
    let shotIndex: Int
    /// The number of decisions the point holds in total.
    let shotsInPoint: Int

    var id: String { "\(pointIndex)-\(shotIndex)-\(question.id)" }
    var isLastOfPoint: Bool { shotIndex == shotsInPoint - 1 }
    var position: RallyPosition { question.position }
}

/// Builds points, not flashcards.
///
/// The single biggest thing separating this app from a quiz was that every
/// generated ball arrived from nowhere and went nowhere. A real point is a
/// sequence: you return, you survive their third, you dink until one of them
/// gives you a ball above the net, and then you finish it. Each of those is a
/// decision the advisor can already grade; what was missing was the thread
/// between them.
///
/// So a point here is an ordered run of phases, and the session is a run of
/// points. Getting a decision right advances the rally. Getting one wrong ends
/// the point, which is exactly what happens on a court and is a far better
/// teacher than a green tick and an unrelated next question.
enum RallyBuilder {

    /// The decisions you actually face in a point, depending on which team you
    /// are on.
    ///
    /// These are YOUR shots only. On the returning team you never hit a third
    /// shot, so the chain skips it; on the serving team you never hit a return.
    /// Getting that wrong would train a sequence that cannot happen.
    static func script(servingTeam: Bool, rng: inout SeededGenerator) -> [RallyPhase] {
        if servingTeam {
            // Serve, then the third, then the walk in, then the kitchen.
            var phases: [RallyPhase] = [.thirdShot, .transition, .dinkRally]
            phases.append([RallyPhase.attack, .defense].randomElement(using: &rng) ?? .attack)
            return phases
        }
        // Return, survive whatever comes back, then the kitchen exchange.
        var phases: [RallyPhase] = [.serveReturn]
        phases.append([RallyPhase.defense, .dinkRally].randomElement(using: &rng) ?? .dinkRally)
        phases.append(.dinkRally)
        phases.append([RallyPhase.attack, .defense].randomElement(using: &rng) ?? .attack)
        return phases
    }

    /// A session of points, flattened into the balls that make them up.
    ///
    /// `ballBudget` is the free tier's remaining allowance, so the last point
    /// is truncated rather than promised and then cut off. A session that says
    /// "point 3" and stops halfway through it is the paywall arriving as a
    /// surprise, which is the thing the lobby check exists to prevent.
    static func session(ballBudget: Int, seed: UInt64, phase: RallyPhase? = nil) -> [RallyBall] {
        guard ballBudget > 0 else { return [] }
        var rng = SeededGenerator(seed: seed)
        var balls: [RallyBall] = []
        var pointIndex = 0

        while balls.count < ballBudget {
            let phases: [RallyPhase]
            if let phase {
                // A single-phase drill is still a point, it is just a point
                // made of one decision repeated. Chaining unrelated phases
                // under a "Dink rally" title would be a different drill than
                // the one the player tapped.
                phases = [phase]
            } else {
                phases = script(servingTeam: Bool.random(using: &rng), rng: &rng)
            }
            let room = ballBudget - balls.count
            let taken = Array(phases.prefix(room))
            for (shotIndex, phase) in taken.enumerated() {
                let question = PositionGenerator.question(
                    phase: phase,
                    seed: seed &+ UInt64((pointIndex &* 1_000 &+ shotIndex) &* 104_729)
                )
                balls.append(RallyBall(
                    question: question,
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

    /// The index of the first ball of the point after `pointIndex`, or nil when
    /// the session is over. Losing a point skips the rest of it: the rally is
    /// dead, and asking someone to keep playing out a point they already lost
    /// is the flashcard behaviour this whole model replaces.
    static func firstBall(after pointIndex: Int, in balls: [RallyBall]) -> Int? {
        balls.firstIndex { $0.pointIndex > pointIndex }
    }
}
