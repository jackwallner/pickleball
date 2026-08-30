import SwiftUI

@main
struct DuprIQApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @StateObject private var subscriptions = SubscriptionService.shared
    @StateObject private var progress = ProgressStore.shared
    @StateObject private var limiter = PracticeLimiter.shared
    @StateObject private var reviews = ReviewPromptTracker.shared
    @StateObject private var settings = AppSettings.shared
    @StateObject private var router = AppRouter.shared
    @StateObject private var profile = PlayerProfile.shared
    @StateObject private var records = PracticeRecordStore.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(subscriptions)
                .environmentObject(progress)
                .environmentObject(limiter)
                .environmentObject(reviews)
                .environmentObject(settings)
                .environmentObject(router)
                .environmentObject(profile)
                .environmentObject(records)
                .onAppear {
                    limiter.rollOverIfNeeded()
                    progress.rollOverIfNeeded()
                    settings.refreshNotificationPermission()
                }
        }
        // A backgrounded app is the normal way a player crosses midnight, and
        // `onAppear` does not fire again on foreground. Without this the free
        // tier stays exhausted into the next day and the only way out is a
        // force quit, which reads as a broken paywall.
        //
        // The entitlement gets the same treatment: a purchase, a restore, or a
        // cancellation can all happen outside the app, and a stale `isPro`
        // either paywalls someone who paid or keeps Pro alive for someone who
        // stopped paying.
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            limiter.rollOverIfNeeded()
            progress.rollOverIfNeeded()
            subscriptions.refreshOnForeground()
            settings.refreshNotificationPermission()
        }
    }
}
