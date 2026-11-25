import Foundation

enum AppStoreLinks {
    /// Numeric Apple ID for `com.jackwallner.pickleball`.
    static let appStoreID = "6804828001"

    /// The listing is live (App Store lookup for this id returns it, and the
    /// marketing site links to it). While it was false every
    /// `apps.apple.com/app/id...` URL built from the id was a 404, so the
    /// funnel used `requestReview()` only.
    static let isListingLive = true

    static var isPublished: Bool { isListingLive && !appStoreID.isEmpty }

    static var productURL: URL? {
        guard isPublished else { return nil }
        return URL(string: "https://apps.apple.com/app/id\(appStoreID)")
    }

    /// The write-a-review page. No storefront prefix: the App Store resolves
    /// the bare app id into the viewer's own storefront, and hardcoding one
    /// only risks sending a reader to the wrong store.
    static var writeReviewURL: URL? {
        guard isPublished else { return nil }
        return URL(string: "https://apps.apple.com/app/id\(appStoreID)?action=write-review")
    }

    /// Matches the address the marketing and support pages publish.
    static let feedbackEmail = "jackwallner+p@gmail.com"
}

/// When the app may put Apple's own rating prompt on screen.
///
/// No question goes in front of it: an "Enjoying it?" step that sent only the
/// yes answers to the App Store is review gating under guideline 5.6.1. The
/// moment is a good run just finished (`ReviewMoment`); this decides whether
/// that moment may ask. From the second cold launch on, at most once every 30
/// days. Apple shows the prompt at most three times a year and decides each
/// time; a call it swallows costs nothing, so the job is to ask early and
/// often inside those limits.
@MainActor
final class ReviewPromptTracker: ObservableObject {
    static let shared = ReviewPromptTracker()

    /// Not in the first session: a second cold launch is the only tenure gate.
    static let minimumLaunchCount = 2
    /// Days between our calls. Paces the asks, not the player's answers.
    static let cooldownDays = 30

    private let defaults: UserDefaults
    private enum Key {
        static let launches = "review.launchCount"
        static let lastAsked = "review.lastAskedDate"
        static let openedWriteReview = "review.openedWriteReview"
        // Written by builds before the good-run moment. Read once so an
        // existing player's next launch is not treated as a first session.
        static let legacySessions = "review.completedSessions"
        static let legacyPrompted = "review.hasPrompted"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var launchCount: Int { max(defaults.integer(forKey: Key.launches), 0) }

    var hasOpenedWriteReview: Bool { defaults.bool(forKey: Key.openedWriteReview) }

    /// Once per cold launch. An install from before this counter existed that
    /// already finished a run starts at one launch behind it, so its first
    /// launch after the update counts as its second.
    func recordAppLaunch() {
        var count = launchCount
        if defaults.object(forKey: Key.launches) == nil, defaults.integer(forKey: Key.legacySessions) > 0 {
            count = 1
        }
        defaults.set(count + 1, forKey: Key.launches)
    }

    /// Whether a good moment right now may call `requestReview()`.
    func shouldRequestReview(now: Date = .now) -> Bool {
        guard !hasOpenedWriteReview else { return false }
        guard launchCount >= Self.minimumLaunchCount else { return false }
        // A stamp from a clock that ran ahead is in the future: no evidence of
        // an ask, and it would hold the cooldown shut for as long.
        guard let last = defaults.object(forKey: Key.lastAsked) as? Date, last <= now else { return true }
        return now.timeIntervalSince(last) >= TimeInterval(Self.cooldownDays) * 86_400
    }

    /// Stamped when the call is made: Apple may show nothing, and there is no
    /// answer to wait for.
    func markAsked(now: Date = .now) {
        defaults.set(now, forKey: Key.lastAsked)
    }

    /// Settings > Rate. The one thing that ends the automatic asks; sending
    /// feedback never does.
    func markOpenedWriteReview(now: Date = .now) {
        defaults.set(true, forKey: Key.openedWriteReview)
        markAsked(now: now)
    }

    func resetForTesting() {
        [Key.launches, Key.lastAsked, Key.openedWriteReview, Key.legacySessions, Key.legacyPrompted]
            .forEach(defaults.removeObject(forKey:))
    }
}

/// The good moment: a run of points finished, not at the free limit, with at
/// least half the graded balls kept in play (the best call or a playable
/// one). It is the end of the core loop, so a typical player reaches it in
/// every session from the first run on.
enum ReviewMoment {
    /// A run cut down to one or two balls is not a result to rate on.
    static let minimumAnswered = 4

    static func isGoodRun(answered: Int, correct: Int, playable: Int, stoppedAtFreeLimit: Bool) -> Bool {
        guard !stoppedAtFreeLimit, answered >= minimumAnswered else { return false }
        return (correct + playable) * 2 >= answered
    }
}
