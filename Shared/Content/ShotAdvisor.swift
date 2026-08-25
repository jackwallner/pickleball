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

    // MARK: - Phases

    private static func serveReturn(_ p: RallyPosition) -> ShotVerdict {
        // The return is the one shot where depth beats everything, including a
        // tempting high ball. Driving a return keeps you at the baseline, which
        // is the mistake the whole phase exists to train out.
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
            the return itself. Driving it low and flat gives them a short ball \
            and leaves you stuck back.
            """,
            targetOpponent: target
        )
    }

    private static func thirdShot(_ p: RallyPosition) -> ShotVerdict {
        if let lagging = p.laggingOpponentSide {
            return ShotVerdict(
                best: Shot(.drive, .atFeet),
                principle: "Drive at the player who isn't set",
                why: """
                \(lagging.label.capitalizedFirst) is still moving through the \
                transition zone. A ball driven at the feet of a player who has \
                not stopped moving is the hardest ball in pickleball to handle, \
                and it is why you look at their feet before you pick this shot. \
                Dropping here would hand them the time they need to reach the \
                line.
                """,
                targetOpponent: lagging
            )
        }
        if p.ballHeight == .aboveNet {
            let target = p.straightOpponentSide
            return ShotVerdict(
                best: Shot(.drive, .backhand),
                principle: "A high ball is a drive, even on the third",
                why: """
                The drop is the default third shot, not a rule. This ball is \
                sitting above net height, so you can drive it flat at the \
                backhand hip of \(target.label), the one directly in front of \
                you, and follow it in. Turning a free ball into a soft drop \
                gives away the one advantage you were handed.
                """,
                targetOpponent: target
            )
        }
        // Both set, ball low: the only question left is which diagonal exists.
        if p.isContactNearMiddle {
            return ShotVerdict(
                best: Shot(.drop, .straightKitchen),
                principle: "From the middle, drop straight",
                why: """
                Both opponents are established at the kitchen and your contact \
                is below the net, so there is no drive available that does not \
                sit up. You are hitting from the middle of the court, which \
                means the cross-court diagonal is barely longer than the \
                straight one: take the shorter, straighter drop in front of you \
                and cut the angle you give back.
                """,
                targetOpponent: nil
            )
        }
        let target = p.crossCourtOpponentSide
        return ShotVerdict(
            best: Shot(.drop, .crossCourtKitchen),
            principle: "Drop when they're set",
            why: """
            Both opponents are established at the kitchen, and your contact is \
            below the net, so there is no drive available that does not sit up. \
            You are wide \(p.contactSideLabel.replacingOccurrences(of: "from ", with: "")), \
            so the drop to \(target.label) travels the longest diagonal, which \
            gives it the most room to land soft and buys you the time to move up.
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
            principle: "Reset off your shoetops, never drive",
            why: """
            You are caught in the transition zone with a ball at or below net \
            height. Take the pace off and land it soft in the kitchen in front \
            of you, then split-step and keep moving forward. The straight reset \
            travels the shortest distance, which is what makes it the one you \
            can control under pressure, and it is the one that does not open an \
            angle while you are still moving.
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
        if p.ballHeight == .netHeight {
            return ShotVerdict(
                best: Shot(.dink, .middle),
                principle: "Middle solves the poach problem",
                why: """
                The ball is at net height: not attackable, but not comfortable \
                for them either. The middle dink makes two players decide who \
                takes it, and indecision between partners produces the popped-up \
                ball you are actually fishing for.
                """,
                targetOpponent: nil
            )
        }
        if p.isMiddleOpen {
            return ShotVerdict(
                best: Shot(.dink, .middle),
                principle: "Dink into the seam they left open",
                why: """
                Contact is below the net with everyone set, so this is a \
                patience ball, and the patient ball is not automatically the \
                cross-court one. They are standing \(feet(p.opponentSpread)) \
                apart: the middle is the widest piece of open kitchen on the \
                court, and a dink into the seam is the one neither of them can \
                take with a comfortable forehand.
                """,
                targetOpponent: nil
            )
        }
        let target = p.crossCourtOpponentSide
        return ShotVerdict(
            best: Shot(.dink, .crossCourtKitchen),
            principle: "Cross-court is the longest, safest diagonal",
            why: """
            Contact is below the net with everyone set at the line and the \
            middle covered, so this is a patience ball. The dink to \
            \(target.label) gives you the longest diagonal and the lowest part \
            of the net, so it is the one you can hit a hundred times without \
            missing. Speeding it up from below the net is how you lose the point \
            you were winning.
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
            front of you, not at the sideline: a ball driven at the body cannot \
            be blocked cleanly.
            """,
            targetOpponent: target
        )
    }

    private static func defense(_ p: RallyPosition) -> ShotVerdict {
        if p.yourZone == .baseline && p.opponentsBothAtKitchen && p.ballHeight == .netHeight {
            let target = p.crossCourtOpponentSide
            return ShotVerdict(
                best: Shot(.lob, .deepCrossCourt),
                principle: "Lob when they crowd the line",
                why: """
                They are both leaning over the kitchen line and you have a ball \
                at a height you can lift. The lob over \(target.label) travels \
                the longest diagonal, so it has the most room to drop in, and it \
                makes them turn and run rather than step back and swing.
                """,
                targetOpponent: target
            )
        }
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
