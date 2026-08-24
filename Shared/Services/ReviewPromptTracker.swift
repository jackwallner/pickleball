import Foundation

/// The fleet review funnel: never call `requestReview()` cold.
///
/// A player has to finish enough drills to have an opinion, then answer an
/// enjoyment gate. Only a Yes reaches Apple's sheet, which is what keeps the
/// one-shot prompt from being spent on someone who is about to one-star.
@MainActor
final class ReviewPromptTracker: ObservableObject {
    static let shared = ReviewPromptTracker()

    /// Sessions finished before the gate is even considered.
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

    /// True when the enjoyment gate should be shown. The gate is not the
    /// review prompt; it is the question that decides whether we ever ask.
    var shouldShowEnjoymentGate: Bool {
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
