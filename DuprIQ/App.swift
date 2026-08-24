import SwiftUI

@main
struct DuprIQApp: App {
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
    }
}
