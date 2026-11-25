import StoreKit
import SwiftUI

extension View {
    /// Calls Apple's rating prompt a few seconds after a good moment, with no
    /// question in front of it. Bump `moment` when the moment happens.
    ///
    /// `isClear` is checked again when the wait is over, so the prompt never
    /// lands on a sheet the player opened in the meantime; the view leaving
    /// the screen cancels it too. A skipped moment is not kept: the next one
    /// asks.
    func requestsReview(after moment: Int, isClear: @escaping () -> Bool) -> some View {
        modifier(ReviewRequestModifier(moment: moment, isClear: isClear))
    }
}

private struct ReviewRequestModifier: ViewModifier {
    /// Long enough for the score to land before the prompt covers it.
    static let delay: Duration = .seconds(3)

    let moment: Int
    let isClear: () -> Bool

    @EnvironmentObject private var reviews: ReviewPromptTracker
    @EnvironmentObject private var subscriptions: SubscriptionService
    @EnvironmentObject private var profile: PlayerProfile
    @Environment(\.requestReview) private var requestReview
    @State private var onScreen = false

    func body(content: Content) -> some View {
        content
            .onAppear { onScreen = true }
            .onDisappear { onScreen = false }
            .onChange(of: moment) { _, _ in schedule() }
    }

    private func mayAsk() -> Bool {
        // Never inside onboarding. RevenueCat's `rating_prompt: off` pauses
        // the asks without a release.
        profile.setupComplete && subscriptions.isOn(.ratingPrompt) && reviews.shouldRequestReview()
    }

    private func schedule() {
        guard mayAsk() else { return }
        Task { @MainActor in
            try? await Task.sleep(for: Self.delay)
            guard onScreen, isClear(), mayAsk() else { return }
            reviews.markAsked()
            requestReview()
        }
    }
}
