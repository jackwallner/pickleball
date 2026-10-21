import SwiftUI

/// Onboarding once, then the court. There is no lobby: opening the app puts
/// you on the court with a ball coming.
struct RootView: View {
    @EnvironmentObject private var subscriptions: SubscriptionService
    @EnvironmentObject private var mastery: MasteryStore
    @EnvironmentObject private var limiter: PracticeLimiter
    @EnvironmentObject private var reviews: ReviewPromptTracker
    @EnvironmentObject private var profile: PlayerProfile

    @State private var ready = false

    var body: some View {
        Group {
            if !ready {
                Theme.background.ignoresSafeArea()
            } else if profile.setupComplete {
                NavigationStack { RallyView() }
            } else {
                OnboardingView()
            }
        }
        .preferredColorScheme(.dark)
        .tint(Theme.courtLight)
        .task {
            // Fixtures first: a screenshot run has to wipe and seed state
            // before the first frame decides what to draw.
            #if DEBUG
            DebugFixtures.applyIfRequested(
                mastery: mastery, limiter: limiter, reviews: reviews, profile: profile
            )
            #endif
            ready = true
            subscriptions.start()
            ConversionDiagnostics.recordAppOpen()
            #if DEBUG
            if RevenueCatProbe.isEnabled { await runRevenueCatProbe() }
            #endif
        }
    }

    #if DEBUG
    /// Same entry points the real paywall calls, so the probe proves the
    /// actual path. Logged rather than asserted, so a missing sheet can be
    /// told apart from a missing offering.
    private func runRevenueCatProbe() async {
        subscriptions.trackPaywallImpression(id: RevenueCatProbe.impressionID)
        guard RevenueCatProbe.wantsPurchase else { return }
        await subscriptions.loadOfferings()
        let package = subscriptions.offerings?.current?.availablePackages.first
        NSLog("RCPROBE offerings=%@ current=%@ packages=%d",
              String(describing: subscriptions.offerings != nil),
              subscriptions.offerings?.current?.identifier ?? "nil",
              subscriptions.offerings?.current?.availablePackages.count ?? -1)
        do {
            let outcome = try await subscriptions.purchase(package)
            NSLog("RCPROBE purchase outcome=%@", String(describing: outcome))
        } catch {
            NSLog("RCPROBE purchase error=%@", String(describing: error))
        }
    }
    #endif
}
