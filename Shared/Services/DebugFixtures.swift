#if DEBUG
import Foundation

/// Deterministic launch state for screenshot and UI-test runs.
///
/// App Store screenshots used to be whatever the simulator happened to be
/// holding: a one-day streak from a previous run, twelve of fifteen free balls
/// left, and phase percentages nobody chose. That is a marketing asset built
/// out of a test account's leftovers. These fixtures replace it with a stated,
/// reproducible story, and the drill seed replaces the wall clock so the
/// captured court is the same court every time.
///
/// Everything here is DEBUG-only and driven by launch arguments, so it cannot
/// reach a release build. `-key value` arguments land in `UserDefaults`
/// automatically via the argument domain, which is why there is no parsing.
@MainActor
enum DebugFixtures {

    enum Key {
        /// `-uitest.reset YES` wipes progress, the daily cap, and review state.
        static let reset = "uitest.reset"
        /// `-uitest.fixture demo` installs the curated practice history below.
        static let fixture = "uitest.fixture"
        /// `-uitest.seed 4242` pins the generated drill instead of using the clock.
        static let seed = "uitest.seed"
        /// `-uitest.skipPrimer YES` suppresses the first-run court primer.
        static let skipPrimer = "uitest.skipPrimer"
    }

    static var requestedSeed: UInt64? {
        let value = UserDefaults.standard.integer(forKey: Key.seed)
        return value > 0 ? UInt64(value) : nil
    }

    static var wantsPrimerSkipped: Bool {
        UserDefaults.standard.bool(forKey: Key.skipPrimer)
            || UserDefaults.standard.string(forKey: Key.fixture) != nil
    }

    /// Called once from `RootView`, before anything renders, so the stores are
    /// mutated rather than raced against.
    static func applyIfRequested(
        progress: ProgressStore,
        limiter: PracticeLimiter,
        reviews: ReviewPromptTracker
    ) {
        let defaults = UserDefaults.standard
        let fixture = defaults.string(forKey: Key.fixture)
        guard defaults.bool(forKey: Key.reset) || fixture != nil else { return }

        progress.resetForTesting()
        limiter.resetForTesting()
        reviews.resetForTesting()
        // The primer flag lives in the same container across runs, so a reset
        // that leaves it set makes the first-run capture impossible to take.
        defaults.removeObject(forKey: CourtPrimerView.seenKey)

        guard fixture == "demo" else { return }
        installDemoHistory(progress: progress, limiter: limiter)
    }

    /// A believable four-week player: strong at the kitchen, leaking points in
    /// transition, which is exactly the story the phase readout exists to tell.
    private static func installDemoHistory(progress: ProgressStore, limiter: PracticeLimiter) {
        let attempts: [String: Int] = [
            RallyPhase.serveReturn.rawValue: 42,
            RallyPhase.thirdShot.rawValue: 38,
            RallyPhase.transition.rawValue: 31,
            RallyPhase.dinkRally.rawValue: 56,
            RallyPhase.attack.rawValue: 27,
            RallyPhase.defense.rawValue: 24,
        ]
        let correct: [String: Int] = [
            RallyPhase.serveReturn.rawValue: 38,
            RallyPhase.thirdShot.rawValue: 29,
            RallyPhase.transition.rawValue: 16,
            RallyPhase.dinkRally.rawValue: 50,
            RallyPhase.attack.rawValue: 21,
            RallyPhase.defense.rawValue: 15,
        ]
        let total = attempts.values.reduce(0, +)

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let plan: [(Int, RallyPhase?, Int, Int)] = [
            (0, nil, 10, 8),
            (0, .transition, 10, 6),
            (1, .dinkRally, 10, 9),
            (2, nil, 10, 7),
            (3, .thirdShot, 10, 8),
            (4, .transition, 10, 5),
            (5, nil, 10, 9),
        ]
        let sessions = plan.map { offset, phase, answered, correctCount in
            SessionRecord(
                id: UUID(),
                date: calendar.date(byAdding: .hour, value: -(offset * 24 + 2), to: today) ?? today,
                phase: phase?.rawValue,
                answered: answered,
                correct: correctCount
            )
        }

        let missed: [MissedPrinciple] = [
            MissedPrinciple(phase: RallyPhase.transition.rawValue,
                            principle: "Reset off your shoetops, never drive",
                            count: 9, lastSeen: today),
            MissedPrinciple(phase: RallyPhase.defense.rawValue,
                            principle: "Reset, don't counter-drive",
                            count: 6, lastSeen: today),
            MissedPrinciple(phase: RallyPhase.thirdShot.rawValue,
                            principle: "Drive at the player who isn't set",
                            count: 5, lastSeen: today),
            MissedPrinciple(phase: RallyPhase.dinkRally.rawValue,
                            principle: "Dink into the seam they left open",
                            count: 3, lastSeen: today),
        ]

        progress.loadForTesting(
            attempts: attempts, correct: correct, streak: 12,
            totalAnswered: total, sessions: sessions, missed: missed
        )
        // Untouched free allowance: the lobby should read as a fresh day.
        limiter.resetForTesting()
        UserDefaults.standard.set(true, forKey: CourtPrimerView.seenKey)
    }
}
#endif
