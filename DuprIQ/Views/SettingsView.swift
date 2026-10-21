import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var profile: PlayerProfile
    @EnvironmentObject private var subscriptions: SubscriptionService

    @State private var showPaywall = false
    @State private var restoreMessage: String?
    @State private var isRestoring = false

    private static let manageURL = URL(string: "https://apps.apple.com/account/subscriptions")!

    var body: some View {
        Form {
            Section {
                Picker("Decision timer", selection: $settings.shotClock) {
                    ForEach(AppSettings.ShotClock.allCases) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .accessibilityIdentifier("settings-timer")
                Toggle("Haptics", isOn: $settings.hapticsEnabled)
            } header: {
                Text("On court")
            } footer: {
                Text("With the timer on, a ball you don't decide on in time is a lost point.")
            }

            Section("You") {
                Picker("Level", selection: $profile.level) {
                    ForEach(ExperienceLevel.allCases) { Text($0.title).tag($0) }
                }
                Picker("Side", selection: $profile.half) {
                    ForEach(CourtHalf.allCases) { Text($0.title).tag($0) }
                }
            }

            Section {
                if subscriptions.isPro {
                    Label("\(AppBrand.proName) is active", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(Theme.rightGreen)
                    Link("Manage subscription", destination: Self.manageURL)
                } else {
                    Button("See \(AppBrand.proName)") { showPaywall = true }
                        .accessibilityIdentifier("settings-pro")
                }
                Button(isRestoring ? "Restoring…" : "Restore purchases", action: restore)
                    .disabled(isRestoring)
                if let restoreMessage {
                    Text(restoreMessage)
                        .font(.footnote)
                        .foregroundStyle(Theme.inkSecondary)
                }
            } header: {
                Text("Membership")
            }

            Section {
                NavigationLink("How answers are decided") { CoachingSystemView() }
                Link("Privacy Policy", destination: PaywallLinks.privacy)
                Link("Terms of Use", destination: PaywallLinks.terms)
                if let mail = URL(string: "mailto:\(AppStoreLinks.feedbackEmail)") {
                    Link("Send feedback", destination: mail)
                }
            } header: {
                Text("About")
            } footer: {
                Text("\(AppBrand.name) \(Self.version). \(AppBrand.disclaimer)")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPaywall) { PaywallView(source: "settings") }
    }

    private static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    private func restore() {
        isRestoring = true
        restoreMessage = nil
        Task {
            defer { isRestoring = false }
            do {
                try await subscriptions.restore()
                restoreMessage = subscriptions.isPro
                    ? "\(AppBrand.proName) restored."
                    : "No previous purchase found on this Apple Account."
            } catch {
                restoreMessage = error.localizedDescription
            }
        }
    }
}

/// The system every answer comes from, stated once so a player can argue with
/// it rather than with an anonymous "correct".
struct CoachingSystemView: View {
    var body: some View {
        List {
            Section {
                Text("Shot selection is coached opinion. \(AppBrand.name) commits to the mainstream doubles system: keep the ball unattackable, get to the kitchen line, and hit the player who isn't set. Every answer names the rule it came from.")
                    .font(.callout)
                    .foregroundStyle(Theme.inkSecondary)
            }
            ForEach(Principle.measured) { principle in
                Section(principle.displayName) {
                    Text(principle.howToSpot)
                        .font(.callout)
                        .foregroundStyle(Theme.inkSecondary)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("How answers are decided")
        .navigationBarTitleDisplayMode(.inline)
    }
}
