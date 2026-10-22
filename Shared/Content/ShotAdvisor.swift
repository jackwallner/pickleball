import Foundation

/// The graded answer for one position: which shot, which named principle it
/// comes from, why the tempting alternative is worse, and which marker on the
/// diagram the ball is going at.
struct ShotVerdict: Equatable, Sendable {
    let best: Shot
    /// The short name of the rule. Shown on the answer card so a player can
    /// argue with the principle rather than with an anonymous "correct".
    let principle: String
    let why: String
    /// The opponent the answer targets, when the answer targets one. The drill
    /// highlights this marker after grading: "hit the player who isn't set" is
    /// only coaching if you can see which player that is.
    let targetOpponent: OpponentSide?

    init(best: Shot, principle: String, why: String, targetOpponent: OpponentSide? = nil) {
        self.best = best
        self.principle = principle
        self.why = why
        self.targetOpponent = targetOpponent
    }
}

/// The rules engine.
///
/// Every answer in the app comes from here, and every answer names the
/// principle it came from. That is deliberate: shot selection is coached
/// opinion, not arithmetic, so the product commits to one stated system
/// (the mainstream "get to the kitchen and keep the ball unattackable"
/// orthodoxy) and shows its reasoning instead of asserting a bare answer.
///
/// The function is total and deterministic: every `RallyPosition` maps to
/// exactly one `ShotVerdict`, which is what makes the generator safe to run
/// forever and what `ShotAdvisorTests` pins down.
///
/// Lateral position is load-bearing, not decoration. Where the contact sits
/// relative to the center line decides whether a long diagonal exists at all,
/// and how far apart the two opponents are standing decides whether the seam
/// between them beats either body. Both reads are mirror-symmetric: reflecting
/// a position across the center line returns the same shot aimed at the other
/// marker, which is the property that stops the drill training a side rather
/// than a decision.
enum ShotAdvisor {

    static func verdict(for position: RallyPosition) -> ShotVerdict {
        switch position.phase {
        case .serveReturn: return serveReturn(position)
        case .thirdShot:   return thirdShot(position)
        case .transition:  return transition(position)
        case .dinkRally:   return dinkRally(position)
        case .attack:      return attack(position)
        case .defense:     return defense(position)
        }
    }

    /// A shot a coach would let go: not the best ball, but no mistake either.
    /// A playable pick keeps the rally alive; only the best one counts as the
    /// right call. Without this tier a straight drop lost the point to a
    /// cross-court drop, which no coach would call a lost point.
    static func isPlayable(_ shot: Shot, in position: RallyPosition, best: Shot) -> Bool {
        guard shot != best,
              MistakeCatalog.pattern(for: shot, in: position, best: best) == nil else { return false }
        let soft: Set<ShotType> = [.drop, .reset, .dink]
        let attack: Set<ShotType> = [.drive, .speedUp, .putAway]
        if soft.contains(best.type), soft.contains(shot.type) { return true }
        if best.type == .deepReturn, shot.type == .deepReturn { return true }
        if attack.contains(best.type), attack.contains(shot.type), position.ballHeight.isAttackable { return true }
        // A drive off a third ball that sits up is a 4.0 play: worse than the
        // drop against two set players, but not a mistake.
        if position.phase == .thirdShot, position.ballHeight == .aboveNet, shot.type == .drive { return true }
        // A defensive lob over a team crowding the line, from the baseline.
        if position.phase == .defense, shot.type == .lob, position.yourZone == .baseline,
           position.opponentsBothAtKitchen, position.ballHeight == .netHeight { return true }
        return false
    }

    // MARK: - Phases

    private static func serveReturn(_ p: RallyPosition) -> ShotVerdict {
        // The return is the one shot where depth beats everything, including a
        // tempting high ball. Driving a return keeps you at the baseline, which
        // is the mistake the whole phase exists to train out.
        if p.isContactNearMiddle || p.isMiddleOpen {
            let reason = p.isMiddleOpen
                ? "They are standing \(feet(p.opponentSpread)) apart, so the middle is the biggest deep target on the court"
                : "You are hitting from the middle, where there is no long diagonal to use"
            return ShotVerdict(
                best: Shot(.deepReturn, .middle),
                principle: "Return deep, then take the line",
                why: """
                A high, deep return pins the serving team behind the baseline and \
                buys you the seconds you need to walk in to the kitchen. \
                \(reason): send it deep down the middle, where both servers \
                hesitate over who takes it and neither gets an angle back at \
                you. A low, hard return gets back to you faster than you can \
                walk in.
                """,
                targetOpponent: nil
            )
        }
        let target = p.crossCourtOpponentSide
        return ShotVerdict(
            best: Shot(.deepReturn, .deepCrossCourt),
            principle: "Return deep, then take the line",
            why: """
            A high, deep return pins the serving team behind the baseline and \
            buys you the seconds you need to walk in to the kitchen. You are \
            hitting \(p.contactSideLabel), so the deep cross-court ball to \
            \(target.label) is the longest one on the court and the one with \
            the most margin. The point is won by getting to the line, not by \
            the return itself. A low, hard return gets back to you faster than \
            you can walk in, and leaves you stuck at the baseline.
            """,
            targetOpponent: target
        )
    }

    private static func thirdShot(_ p: RallyPosition) -> ShotVerdict {
        if let lagging = p.laggingOpponentSide {
            if p.ballHeight == .aboveNet {
                return ShotVerdict(
                    best: Shot(.drive, .atFeet),
                    principle: "Drive at the player who isn't set",
                    why: """
                    \(lagging.label.capitalizedFirst) is still moving through the \
                    transition zone and this ball sits up. A ball driven at the \
                    feet of a player who has not stopped moving is the hardest \
                    one to handle; be ready to drop the next ball and follow it in.
                    """,
                    targetOpponent: lagging
                )
            }
            return ShotVerdict(
                best: Shot(.drop, .atFeet),
                principle: "Drop at the player who isn't set",
                why: """
                \(lagging.label.capitalizedFirst) is still moving up, and your \
                contact is too low to drive. Drop it at their feet: a soft ball \
                landing on a moving player forces a low pickup, and the ball \
                they lift is the one you attack once you are in.
                """,
                targetOpponent: lagging
            )
        }
        // Both set. The drop is the third shot even off a ball that sits up:
        // a drive from the baseline at two players already at the line comes
        // back at your feet before you have taken a step.
        let opening = p.ballHeight == .aboveNet
            ? "The ball sits up and a drive is tempting, but both opponents are set at the line, and a drive from back here comes straight back at your feet."
            : "Both opponents are set at the kitchen and your contact is below the net, so any drive has to come up and sits up for them."
        if p.isContactNearMiddle {
            return ShotVerdict(
                best: Shot(.drop, .straightKitchen),
                principle: "From the middle, drop straight",
                why: """
                \(opening) You are hitting from the middle, where the cross-court \
                diagonal is barely longer than the straight one: take the \
                straighter drop in front of you and cut the angle you give back.
                """,
                targetOpponent: nil
            )
        }
        let target = p.crossCourtOpponentSide
        return ShotVerdict(
            best: Shot(.drop, .crossCourtKitchen),
            principle: "Drop when they're set",
            why: """
            \(opening) You are hitting \(p.contactSideLabel), so the drop to \
            \(target.label) travels the longest diagonal, which gives it the \
            most court to land soft and buys you the time to move up.
            """,
            targetOpponent: target
        )
    }

    private static func transition(_ p: RallyPosition) -> ShotVerdict {
        if p.ballHeight == .aboveNet {
            let target = p.isMiddleOpen ? nil : p.laggingOpponentSide ?? p.straightOpponentSide
            return ShotVerdict(
                best: Shot(.drive, p.isMiddleOpen ? .middle : .atFeet),
                principle: p.isMiddleOpen
                    ? "Take the free ball through the seam"
                    : "Take the free ball in transition",
                why: p.isMiddleOpen ? """
                You are mid-court and the ball is above the net. They have both \
                drifted wide, so the seam between them is open: step in and \
                drive it down the middle, where neither of them owns the ball \
                and both have to reach across their body.
                """ : """
                You are mid-court and the ball is above the net. Step in and \
                drive it down at the feet of \(target?.label ?? "the player in front of you"). \
                Resetting a ball you could have hit down is how a neutral rally \
                becomes a defensive one.
                """,
                targetOpponent: target
            )
        }
        return ShotVerdict(
            best: Shot(.reset, .straightKitchen),
            principle: "Reset in transition",
            why: """
            You are caught in the transition zone with a ball that is not above \
            the net, and a drive from here has to come up. Take the pace off \
            and land it soft in the kitchen, then split-step and keep moving \
            forward. The straight reset travels the shortest distance, which \
            makes it the easiest to control while you are still moving.
            """,
            targetOpponent: nil
        )
    }

    private static func dinkRally(_ p: RallyPosition) -> ShotVerdict {
        if let lagging = p.laggingOpponentSide {
            return ShotVerdict(
                best: Shot(.dink, .atFeet),
                principle: "Dink at the player who isn't set",
                why: """
                A dink rally does not mean you stop reading their feet. \
                \(lagging.label.capitalizedFirst) has not re-established at the \
                line, so a soft ball at their feet makes them hit up, and the \
                ball that comes back is the one you attack.
                """,
                targetOpponent: lagging
            )
        }
        if p.isMiddleOpen {
            return ShotVerdict(
                best: Shot(.dink, .middle),
                principle: "Dink into the seam they left open",
                why: """
                The ball is not above the net and everyone is set, so this is a \
                patience ball, and the patient ball is not automatically the \
                cross-court one. They are standing \(feet(p.opponentSpread)) \
                apart: the middle is the widest piece of open kitchen on the \
                court, and a dink into the seam makes them decide who takes it. \
                That moment of doubt is where the ball that pops up comes from.
                """,
                targetOpponent: nil
            )
        }
        let target = p.crossCourtOpponentSide
        return ShotVerdict(
            best: Shot(.dink, .crossCourtKitchen),
            principle: "Cross-court is the longest, safest diagonal",
            why: """
            The ball is not above the net, everyone is set at the line and the \
            middle is covered, so this is a patience ball. The dink to \
            \(target.label) gives you the longest diagonal and the lowest part \
            of the net, so it is the one you can hit a hundred times without \
            missing. Speeding up a ball that is not above the net is how you \
            lose the point you were winning.
            """,
            targetOpponent: target
        )
    }

    private static func attack(_ p: RallyPosition) -> ShotVerdict {
        if let lagging = p.laggingOpponentSide {
            return ShotVerdict(
                best: Shot(.drive, .atFeet),
                principle: "Attack the player who isn't set",
                why: """
                The ball is above the net and \(lagging.label) is still moving. \
                Drive it at their feet rather than trying to thread a winner \
                past the player who is already set at the line.
                """,
                targetOpponent: lagging
            )
        }
        if p.isMiddleOpen {
            return ShotVerdict(
                best: Shot(.putAway, .middle),
                principle: "Finish through the seam",
                why: """
                The ball is above net height and they are standing \
                \(feet(p.opponentSpread)) apart. The gap between two set \
                players is normally the smallest target on the court; here it \
                is the biggest. Hit down through the middle, where a ball needs \
                two people to agree before either of them moves.
                """,
                targetOpponent: nil
            )
        }
        let target = p.straightOpponentSide
        return ShotVerdict(
            best: Shot(.putAway, .atFeet),
            principle: "Finish down at the feet",
            why: """
            The ball is above net height with both opponents at the line and \
            the middle covered, so you can hit down but you cannot hit through. \
            Aim at the feet and the hip of \(target.label), the one straight in \
            front of you, not at the sideline: a ball at the hip is the hardest \
            one to block back with control.
            """,
            targetOpponent: target
        )
    }

    private static func defense(_ p: RallyPosition) -> ShotVerdict {
        return ShotVerdict(
            best: Shot(.reset, .straightKitchen),
            principle: "Reset, don't counter-drive",
            why: """
            You are under pressure with a low ball. The instinct is to swing \
            harder, and it is wrong: a counter-drive from below the net sits up \
            for whoever is at the line. Take the pace off, land it in the \
            kitchen in front of you, and turn a defensive ball back into a \
            neutral one.
            """,
            targetOpponent: nil
        )
    }

    // MARK: - Helpers

    private static func feet(_ value: Double) -> String {
        "about \(Int(value.rounded())) feet"
    }
}

extension String {
    /// Upper-cases only the first character, so "the left opponent" can open a
    /// sentence without `capitalized` shouting every word.
    var capitalizedFirst: String {
        guard let first else { return self }
        return String(first).uppercased() + dropFirst()
    }
}
