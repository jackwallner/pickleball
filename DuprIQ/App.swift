import SwiftUI

@main
struct DuprIQApp: App {
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var subscriptions = SubscriptionService.shared
    @StateObject private var progress = ProgressStore.shared
    @StateObject private var limiter = PracticeLimiter.shared
    @StateObject private var reviews = ReviewPromptTracker.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(subscriptions)
                .environmentObject(progress)
                .environmentObject(limiter)
                .environmentObject(reviews)
                .task { subscriptions.start() }
                .onAppear { limiter.rollOverIfNeeded() }
        }
        // A backgrounded app is the normal way a player crosses midnight, and
        // `onAppear` does not fire again on foreground. Without this the free
        // tier stays exhausted into the next day and the only way out is a
        // force quit, which reads as a broken paywall.
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            limiter.rollOverIfNeeded()
        }
    }
}
