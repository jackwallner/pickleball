import SwiftUI

struct RootView: View {
    @EnvironmentObject private var subscriptions: SubscriptionService
    @EnvironmentObject private var progress: ProgressStore
    @EnvironmentObject private var limiter: PracticeLimiter
    @EnvironmentObject private var reviews: ReviewPromptTracker
    @EnvironmentObject private var settings: AppSettings

    @State private var showPrimer = false
    @State private var showOnboarding = false

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Practice", systemImage: "figure.pickleball") }
            ProgressDashboardView()
                .tabItem { Label("Progress", systemImage: "chart.bar.fill") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .tint(Theme.court)
        .preferredColorScheme(settings.appearance.colorScheme)
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView {
                showOnboarding = false
                // The primer is a separate, shorter thing: onboarding says what
                // the app is, the primer teaches the court the drills draw. Only
                // offer it once onboarding is out of the way.
                if !UserDefaults.standard.bool(forKey: CourtPrimerView.seenKey) {
                    showPrimer = true
                }
            }
        }
        .sheet(isPresented: $showPrimer) {
            CourtPrimerView(isFirstRun: true)
        }
        .task {
            // Fixtures first: a screenshot run has to be able to wipe and seed
            // state before the first frame decides what to draw.
            #if DEBUG
            DebugFixtures.applyIfRequested(
                progress: progress, limiter: limiter, reviews: reviews
            )
            if DebugFixtures.wantsPrimerSkipped {
                UserDefaults.standard.set(true, forKey: CourtPrimerView.seenKey)
                progress.hasOnboarded = true
            }
            #endif
            subscriptions.start()

            if !progress.hasOnboarded {
                showOnboarding = true
                return
            }
            // The court is the task. Someone who cannot read the diagram cannot
            // answer the first question, and the coaching explanation buried in
            // Settings is three taps too far from that moment.
            // Read the store rather than an @AppStorage mirror: the fixture
            // above may have just cleared this key, and the property wrapper
            // can still be holding the value it cached for this render.
            if !UserDefaults.standard.bool(forKey: CourtPrimerView.seenKey) {
                showPrimer = true
            }
        }
    }
}
