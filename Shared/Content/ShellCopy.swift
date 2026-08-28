import Foundation

/// Player-facing strings that live in the shell rather than in a drill.
///
/// This file exists because of how the app was built. The shell was ported from
/// another app in the fleet, and a port's most embarrassing failure mode is a
/// leftover word from the previous domain surfacing in a notification, a tour
/// page or a completion screen, where no drill test would ever look at it.
/// Collecting them here gives `ShellCopyTests` one place to read, so a stray
/// "conductor" or "tile" cannot hide in the chrome.
enum ShellCopy {
    enum DailyReminder {
        static let title = "Time for a few balls"
        static let body = "Five minutes on the phase you keep missing beats another hour of open play."
    }

    enum MatchWarmUpReminder {
        static let title = "Your warm-up is ready"
        static let body = "Five targeted minutes now makes the first game feel slower."
    }

    enum Tour {
        static let courtsBody = "Each court holds its own drills: the court and the rules, the soft game at the kitchen, the third shot and the walk in, and attack and defense. The two opening courts are free, forever."
        static let proLockedBody = "Daily Drill gives every member the same five balls, Match Warm-Up targets your weakest phase before you play, and Endless Practice never runs out. Nothing you have now goes away. Unlock any time from Home or Settings."
    }

    enum DrillComplete {
        static let flashcardsSubhead = "Every card reviewed. The vocabulary is what makes the reads repeatable."
        static let scoredSubhead = "Every position you read here is one you'll read faster on court."
    }

    enum Onboarding {
        static let freeCourtsBenefit = "Two full courts, free forever"
        static let generatorBenefit = "Positions that never repeat"
        static let principleBenefit = "Every answer names its principle"
    }

    /// The disclaimer that has to survive every redesign.
    ///
    /// The app is not affiliated with Dynamic Universal Pickleball Rating and
    /// must never look like it reports or requires an official rating. This
    /// string is read by the copy test for exactly that reason.
    enum Legal {
        static let duprDisclaimer = "Not affiliated with, endorsed by, or connected to Dynamic Universal Pickleball Rating."
    }

    static var all: [String] {
        [
            DailyReminder.title, DailyReminder.body,
            MatchWarmUpReminder.title, MatchWarmUpReminder.body,
            Tour.courtsBody, Tour.proLockedBody,
            DrillComplete.flashcardsSubhead, DrillComplete.scoredSubhead,
            Onboarding.freeCourtsBenefit, Onboarding.generatorBenefit,
            Onboarding.principleBenefit,
            Legal.duprDisclaimer,
        ]
    }
}
