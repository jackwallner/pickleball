import Foundation

enum AppStoreLinks {
    /// Numeric Apple ID for `com.jackwallner.pickleball`.
    static let appStoreID = "6804828001"

    /// FLIP THIS THE DAY THE LISTING GOES READY FOR SALE, and not before.
    ///
    /// Having an Apple ID is not the same as having a listing. The ASC record
    /// has existed since before there was anything to link to, and while it
    /// sits in PREPARE_FOR_SUBMISSION every `apps.apple.com/app/id...` URL
    /// built from it is a 404. Treating a non-empty id as "published" would
    /// hand TestFlight testers a dead link and offer a store page that does not
    /// exist, which is the worst first impression a funnel can make.
    ///
    /// While this is false the funnel uses `requestReview()` only. The feedback
    /// path still works, and that is the one that matters pre-launch.
    static let isListingLive = false

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

/// When to call Apple's review prompt. A player has to finish enough drills to
/// have an opinion first, and then the prompt is asked directly with no
/// "Enjoying it?" question in front of it: guideline 5.6.1 rejects sending only
/// the yes answers to the App Store.
@MainActor
final class ReviewPromptTracker: ObservableObject {
    static let shared = ReviewPromptTracker()

    /// Sessions finished before the prompt is considered.
    private let sessionThreshold = 3

    @Published private(set) var completedSessions: Int
    @Published private(set) var hasPrompted: Bool

    private let defaults: UserDefaults
    private enum Key {
        static let sessions = "review.completedSessions"
        static let prompted = "review.hasPrompted"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        completedSessions = defaults.integer(forKey: Key.sessions)
        hasPrompted = defaults.bool(forKey: Key.prompted)
    }

    func recordSessionFinished() {
        completedSessions += 1
        defaults.set(completedSessions, forKey: Key.sessions)
    }

    /// True when the host should call `requestReview()` and then
    /// `markPrompted()`.
    var shouldRequestReview: Bool {
        !hasPrompted && completedSessions >= sessionThreshold
    }

    func markPrompted() {
        hasPrompted = true
        defaults.set(true, forKey: Key.prompted)
    }

    func resetForTesting() {
        completedSessions = 0
        hasPrompted = false
        defaults.set(0, forKey: Key.sessions)
        defaults.set(false, forKey: Key.prompted)
    }
}
