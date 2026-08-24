import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var subscriptions: SubscriptionService
    @EnvironmentObject private var progress: ProgressStore
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            List {
                Section("Subscription") {
                    LabeledContent("Status", value: subscriptions.isPro ? "Pro" : "Free")
                    if !subscriptions.isPro {
                        Button("See Pro") { showPaywall = true }
                    }
                    Button("Restore purchases") {
                        Task { try? await subscriptions.restore() }
                    }
                }

                Section {
                    NavigationLink("How the answers are decided") { CoachingSystemView() }
                    Link("Privacy Policy", destination: PaywallLinks.privacy)
                    Link("Terms of Use", destination: PaywallLinks.terms)
                }

                #if DEBUG
                Section("Developer") {
                    Toggle("Local Pro override", isOn: Binding(
                        get: { subscriptions.isPro },
                        set: { subscriptions.setLocalOverride(isPro: $0) }
                    ))
                    Button("Reset progress", role: .destructive) {
                        progress.resetForTesting()
                    }
                }
                #endif
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showPaywall) { PaywallView() }
        }
    }
}

/// Shot selection is coached opinion, so the app states its system rather than
/// asserting bare answers. This screen is the honest version of that promise,
/// and it is also the first place a 4.0 player looks before leaving a review.
struct CoachingSystemView: View {
    var body: some View {
        List {
            Section {
                Text("""
                Every answer in DUPR IQ comes from one stated system: keep the \
                ball unattackable, get to the kitchen line, and hit at the \
                player who is not set yet. It is the mainstream doubles \
                orthodoxy taught by most coaches, and the app names the \
                principle behind each answer so you can disagree with the \
                principle rather than with an anonymous "correct".
                """)
            }
            Section("The principles") {
                ForEach(RallyPhase.allCases) { phase in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(phase.title).font(.subheadline.weight(.semibold))
                        Text(phase.subtitle).font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
            Section {
                Text("""
                Situations where a good player would reasonably pick something \
                else exist, and the explanation says so when they do. If you \
                think an answer is wrong, the principle name is the thing to \
                argue with.
                """)
                .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("The system")
        .navigationBarTitleDisplayMode(.inline)
    }
}
