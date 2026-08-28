import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var subscriptions: SubscriptionService
    @EnvironmentObject private var progress: ProgressStore
    @EnvironmentObject private var limiter: PracticeLimiter
    @EnvironmentObject private var reviews: ReviewPromptTracker
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var profile: PlayerProfile
    @State private var showPaywall = false
    @State private var showTour = false
    @State private var showPrimer = false
    @State private var restoreMessage: String?
    @State private var isRestoring = false

    var body: some View {
        NavigationStack {
            List {
                Section("Subscription") {
                    LabeledContent("Status", value: subscriptions.isPro ? "Pro" : "Free")
                    if !subscriptions.isPro {
                        Button("See Pro") { showPaywall = true }
                            .accessibilityIdentifier("see-pro")
                    }
                    Button("Restore purchases") { restore() }
                        .disabled(isRestoring)
                        .accessibilityIdentifier("restore-purchases")
                    if let restoreMessage {
                        Text(restoreMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Your game") {
                    NavigationLink {
                        PlayerProfileView()
                    } label: {
                        LabeledContent("Level", value: profile.levelSummary)
                    }
                    if let days = profile.daysUntilMatch {
                        LabeledContent("Next match", value: days == 0 ? "Today" : "\(days) days")
                    }
                }

                Section("Appearance") {
                    Picker("Theme", selection: $settings.appearance) {
                        ForEach(AppSettings.Appearance.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                }

                Section("Feedback") {
                    Toggle("Haptics", isOn: $settings.hapticsEnabled)
                    Toggle("Sound", isOn: $settings.soundEnabled)
                    Toggle("Celebrations", isOn: $settings.celebrationsEnabled)
                }

                Section {
                    Toggle("Daily reminder", isOn: $settings.reminderEnabled)
                    if settings.reminderEnabled {
                        DatePicker(
                            "Remind me at",
                            selection: $settings.reminderTime,
                            displayedComponents: .hourAndMinute
                        )
                    }
                } header: {
                    Text("Reminders")
                } footer: {
                    Text(ShellCopy.DailyReminder.body)
                }

                Section("Learn") {
                    Button("How to read the court") { showPrimer = true }
                        .accessibilityIdentifier("settings-primer")
                    NavigationLink("The quick-start primer") { HowToPlayView() }
                    NavigationLink("How the answers are decided") { CoachingSystemView() }
                    Button("What this app can do") { showTour = true }
                }

                Section {
                    Link("Privacy Policy", destination: PaywallLinks.privacy)
                    Link("Terms of Use", destination: PaywallLinks.terms)
                } footer: {
                    Text(ShellCopy.Legal.duprDisclaimer)
                }

                #if DEBUG
                Section("Developer") {
                    Toggle("Local Pro override", isOn: Binding(
                        get: { subscriptions.isPro },
                        set: { subscriptions.setLocalOverride(isPro: $0) }
                    ))
                    .accessibilityIdentifier("local-pro")
                    Button("Reset progress", role: .destructive) {
                        progress.resetForTesting()
                        limiter.resetForTesting()
                        reviews.resetForTesting()
                    }
                    .accessibilityIdentifier("reset-progress")
                }
                #endif
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .sheet(isPresented: $showPrimer) { CourtPrimerView() }
            .sheet(isPresented: $showTour) { FeatureTourView { showTour = false } }
        }
    }

    /// Restore has to say something. A button that silently does nothing is
    /// what App Review reads as a broken restore path.
    private func restore() {
        isRestoring = true
        restoreMessage = nil
        Task {
            defer { isRestoring = false }
            do {
                try await subscriptions.restore()
                restoreMessage = subscriptions.isPro
                    ? "Pro restored."
                    : "No previous purchase found on this Apple Account."
            } catch {
                restoreMessage = error.localizedDescription
            }
        }
    }
}

/// Shot selection is coached opinion, so the app states its system rather than
/// asserting bare answers. This screen is the honest version of that promise,
/// and it is also the first place a 4.0 player looks before leaving a review.
struct CoachingSystemView: View {
    @Environment(\.dismiss) private var dismiss
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
            // The nine principles, read straight off the enum the advisor and
            // the Which Principle? drill both use. A hand-written second copy
            // of this list is a copy that drifts, and the one place a player
            // checks the system is the worst place for it to be out of date.
            Section("The principles") {
                ForEach(Principle.allCases) { principle in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(principle.displayName).font(.subheadline.weight(.semibold))
                        Text(principle.howToSpot)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(principle.tag)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 4)
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
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Label("Back", systemImage: "chevron.left")
                }
                .accessibilityIdentifier("nav-back")
            }
        }
    }
}
