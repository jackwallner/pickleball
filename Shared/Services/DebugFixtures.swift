#if DEBUG
import Foundation

/// Deterministic launch state for screenshot and UI-test runs, driven by
/// launch arguments (`-key value` lands in `UserDefaults` via the argument
/// domain). DEBUG only, so none of it can reach a release build.
@MainActor
enum DebugFixtures {

    enum Key {
        /// `-uitest.reset YES` wipes mastery, the daily cap, the profile and review state.
        static let reset = "uitest.reset"
        /// `-uitest.fixture demo` installs the curated history below and skips onboarding.
        static let fixture = "uitest.fixture"
        /// `-uitest.seed 4242` pins the generated court instead of using the clock.
        static let seed = "uitest.seed"
        /// `-uitest.freeLeft 1` leaves that many free balls today, so a test
        /// reaches the daily limit without playing fifteen.
        static let freeLeft = "uitest.freeLeft"
        /// Simulate a calendar-day change without changing the simulator's clock.
        static let rolloverAfter = "uitest.rolloverAfter"
    }

    static var requestedSeed: UInt64? {
        let value = UserDefaults.standard.integer(forKey: Key.seed)
        return value > 0 ? UInt64(value) : nil
    }

    /// Called once from `RootView`, before anything renders.
    static func applyIfRequested(
        mastery: MasteryStore,
        limiter: PracticeLimiter,
        reviews: ReviewPromptTracker,
        profile: PlayerProfile
    ) {
        let defaults = UserDefaults.standard
        let fixture = defaults.string(forKey: Key.fixture)
        guard defaults.bool(forKey: Key.reset) || fixture != nil else { return }

        mastery.resetForTesting()
        limiter.resetForTesting()
        reviews.resetForTesting()
        profile.resetForTesting()
        if let left = Int(defaults.string(forKey: Key.freeLeft) ?? "") {
            limiter.useForTesting(PracticeLimiter.freeDailyBalls - left)
        }
        if let delay = Double(defaults.string(forKey: Key.rolloverAfter) ?? ""), delay > 0 {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(delay))
                let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
                defaults.set(yesterday, forKey: "limiter.day")
                NotificationCenter.default.post(name: .NSCalendarDayChanged, object: nil)
            }
        }

        guard fixture == "demo" else { return }
        profile.level = .improving
        profile.markSetupComplete()
        mastery.load(demoState())
    }

    /// A believable four-week player: strong at the kitchen, leaking points in
    /// transition, which is the story "Your game" exists to tell.
    private static func demoState() -> MasteryState {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        var state = MasteryState()
        let families: [(Principle, Int, Int)] = [
            (.returnDeep, 42, 38), (.unattackable, 31, 24), (.getToTheLine, 18, 13),
            (.hitWhoIsntSet, 47, 33), (.middleSeam, 29, 24), (.longestDiagonal, 38, 34),
            (.reset, 36, 19), (.finishDown, 27, 22),
        ]
        for (family, tried, right) in families {
            state.attempts[family.rawValue] = tried
            state.correct[family.rawValue] = right
        }
        let phases: [(RallyPhase, Int, Int)] = [
            (.serveReturn, 42, 38), (.thirdShot, 38, 29), (.transition, 31, 16),
            (.dinkRally, 56, 50), (.attack, 27, 21), (.defense, 24, 15),
        ]
        for (phase, tried, right) in phases {
            state.phaseAttempts[phase.rawValue] = tried
            state.phaseCorrect[phase.rawValue] = right
        }
        state.totalAnswered = phases.map(\.1).reduce(0, +)
        state.mistakes = [
            MistakeTally(id: "counter-drove-under-pressure", phase: RallyPhase.transition.rawValue,
                         misses: 9, fixes: 2, lastMissed: today),
            MistakeTally(id: "hit-the-player-who-was-set", phase: RallyPhase.thirdShot.rawValue,
                         misses: 6, fixes: 1, lastMissed: today),
            MistakeTally(id: "attacked-a-low-ball", phase: RallyPhase.dinkRally.rawValue,
                         misses: 4, fixes: 4, lastMissed: today),
        ]
        state.rallies = (0..<7).map { offset in
            RallyRecord(
                id: UUID(),
                date: calendar.date(byAdding: .hour, value: -(offset * 24 + 2), to: today) ?? today,
                pointsWon: [3, 2, 4, 2, 3, 1, 4][offset],
                pointsLost: [2, 3, 1, 3, 2, 4, 1][offset],
                answered: 12,
                correct: [9, 8, 11, 7, 9, 6, 11][offset]
            )
        }
        state.streak = 12
        state.lastPracticeDay = calendar.date(byAdding: .day, value: -1, to: today)
        return state
    }
}
#endif
