import Foundation

/// The graded answer for one position: which shot, which named principle it
/// comes from, and why the tempting alternative is worse.
struct ShotVerdict: Equatable, Sendable {
    let best: Shot
    /// The short name of the rule. Shown on the answer card so a player can
    /// argue with the principle rather than with an anonymous "correct".
    let principle: String
    let why: String
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
        ShotVerdict(
            best: Shot(.deepReturn, .deepCrossCourt),
            principle: "Return deep, then take the line",
            why: """
            A high, deep return pins the serving team behind the baseline and \
            buys you the seconds you need to walk in to the kitchen. The point \
            is won by getting to the line, not by the return itself. Driving it \
            low and flat gives them a short ball and leaves you stuck back.
            """
        )
    }

    private static func thirdShot(_ p: RallyPosition) -> ShotVerdict {
        if p.laggingOpponent != nil {
            return ShotVerdict(
                best: Shot(.drive, .atFeet),
                principle: "Drive at the player who isn't set",
                why: """
                One of them is still moving through the transition zone. A ball \
                driven at the feet of a player who has not stopped moving is the \
                hardest ball in pickleball to handle, and it is why you look at \
                their feet before you pick this shot. Dropping here would hand \
                them the time they need to reach the line.
                """
            )
        }
        if p.ballHeight == .aboveNet {
            return ShotVerdict(
                best: Shot(.drive, .backhand),
                principle: "A high ball is a drive, even on the third",
                why: """
                The drop is the default third shot, not a rule. This ball is \
                sitting above net height, so you can drive it flat at the \
                backhand hip and follow it in. Turning a free ball into a soft \
                drop gives away the one advantage you were handed.
                """
            )
        }
        return ShotVerdict(
            best: Shot(.drop, .crossCourtKitchen),
            principle: "Drop when they're set",
            why: """
            Both opponents are established at the kitchen, and your contact is \
            below the net, so there is no drive available that does not sit up. \
            The cross-court drop travels the longest diagonal, which gives it \
            the most room to land soft, and it buys you the time to move up.
            """
        )
    }

    private static func transition(_ p: RallyPosition) -> ShotVerdict {
        if p.ballHeight == .aboveNet {
            return ShotVerdict(
                best: Shot(.drive, .atFeet),
                principle: "Take the free ball in transition",
                why: """
                You are mid-court and the ball is above the net. Step in and \
                drive it down at their feet. Resetting a ball you could have \
                hit down is how a neutral rally becomes a defensive one.
                """
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
            can control under pressure.
            """
        )
    }

    private static func dinkRally(_ p: RallyPosition) -> ShotVerdict {
        if p.laggingOpponent != nil {
            return ShotVerdict(
                best: Shot(.dink, .atFeet),
                principle: "Dink at the player who isn't set",
                why: """
                A dink rally does not mean you stop reading their feet. One \
                opponent has not re-established at the line, so a soft ball at \
                their feet makes them hit up, and the ball that comes back is \
                the one you attack.
                """
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
                """
            )
        }
        return ShotVerdict(
            best: Shot(.dink, .crossCourtKitchen),
            principle: "Cross-court is the longest, safest diagonal",
            why: """
            Contact is below the net with everyone set at the line, so this is a \
            patience ball. Cross-court gives you the longest diagonal and the \
            lowest part of the net, so it is the dink you can hit a hundred times \
            without missing. Speeding it up from below the net is how you lose \
            the point you were winning.
            """
        )
    }

    private static func attack(_ p: RallyPosition) -> ShotVerdict {
        if p.laggingOpponent != nil {
            return ShotVerdict(
                best: Shot(.drive, .atFeet),
                principle: "Attack the player who isn't set",
                why: """
                The ball is above the net and one of them is still moving. Drive \
                it at their feet rather than trying to thread a winner past the \
                player who is already set at the line.
                """
            )
        }
        return ShotVerdict(
            best: Shot(.putAway, .atFeet),
            principle: "Finish down at the feet",
            why: """
            The ball is above net height with both opponents at the line, so you \
            can hit down on it. Aim at the feet and the hip, not the sideline: \
            the gap between two set players is small, and a ball driven at the \
            body cannot be blocked cleanly.
            """
        )
    }

    private static func defense(_ p: RallyPosition) -> ShotVerdict {
        if p.yourZone == .baseline && p.opponentsBothAtKitchen && p.ballHeight == .netHeight {
            return ShotVerdict(
                best: Shot(.lob, .deepCrossCourt),
                principle: "Lob when they crowd the line",
                why: """
                They are both leaning over the kitchen line and you have a ball \
                at a height you can lift. The cross-court lob travels the longest \
                distance, so it has the most room to drop in, and it makes the \
                player with the weaker overhead turn and run.
                """
            )
        }
        return ShotVerdict(
            best: Shot(.reset, .straightKitchen),
            principle: "Reset, don't counter-drive",
            why: """
            You are under pressure with a low ball. The instinct is to swing \
            harder, and it is wrong: a counter-drive from below the net sits up \
            for whoever is at the line. Take the pace off, land it in the \
            kitchen, and turn a defensive ball back into a neutral one.
            """
        )
    }
}
