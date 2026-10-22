import SwiftUI

@main
struct DuprIQApp: App {
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var subscriptions = SubscriptionService.shared
    @StateObject private var mastery = MasteryStore.shared
    @StateObject private var limiter = PracticeLimiter.shared
    @StateObject private var reviews = ReviewPromptTracker.shared
    @StateObject private var settings = AppSettings.shared
    @StateObject private var profile = PlayerProfile.shared

    // Fixtures before the first frame: a screenshot run has to wipe and seed
    // state before RootView decides what to draw, and a blank holding frame
    // while it waited added to the launch.
    init() {
        #if DEBUG
        DebugFixtures.applyIfRequested(
            mastery: .shared, limiter: .shared, reviews: .shared, profile: .shared
        )
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(subscriptions)
                .environmentObject(mastery)
                .environmentObject(limiter)
                .environmentObject(reviews)
                .environmentObject(settings)
                .environmentObject(profile)
                .onAppear {
                    limiter.rollOverIfNeeded()
                    mastery.rollOverIfNeeded()
                }
        }
        // A backgrounded app is how a player crosses midnight, and `onAppear`
        // does not fire again on foreground. The entitlement gets the same
        // treatment: a purchase, restore or cancellation can happen outside.
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            limiter.rollOverIfNeeded()
            mastery.rollOverIfNeeded()
            subscriptions.refreshOnForeground()
        }
    }
}
