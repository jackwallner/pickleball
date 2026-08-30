import SwiftUI

enum PaywallLinks {
    static let terms = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    static let privacy = URL(string: "https://jackwallner.github.io/pickleball/privacy-policy")!
}

enum PaywallPlan: String, CaseIterable, Identifiable {
    case yearly, monthly, lifetime
    var id: String { rawValue }

    var title: String {
        switch self {
        case .yearly: return "Yearly"
        case .monthly: return "Monthly"
        case .lifetime: return "Lifetime"
        }
    }
}

struct PaywallView: View {
    @EnvironmentObject private var subscriptions: SubscriptionService
    @Environment(\.dismiss) private var dismiss

    /// Where the sheet was opened from. Not sent anywhere: it exists so the
    /// call sites read as distinct entry points and a future funnel question
    /// ("which door do people buy from") has somewhere to hang.
    var source: String = "unspecified"

    @State private var plan: PaywallPlan = .yearly
    @State private var isWorking = false
    @State private var error: String?

    private var isStoreReady: Bool {
        isPlanAvailable(plan)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Every ball, every phase")
                        .font(.largeTitle.bold())

                    if subscriptions.storeState == .unavailable {
                        unavailableCard
                    }

                    ForEach(PaywallPlan.allCases) { option in
                        planRow(option)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Self.benefits, id: \.self) { benefit in
                            Label(benefit, systemImage: "checkmark.circle.fill")
                                .font(.callout)
                        }
                    }
                }
                .padding()
            }
            .safeAreaInset(edge: .bottom) {
                footer
            }
            .navigationTitle("DUPR IQ Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not now") { dismiss() }
                }
            }
            .task {
                await subscriptions.ensureOfferings()
                selectAvailablePlanIfNeeded()
                subscriptions.trackPaywallImpression(id: "main_paywall", oncePerSession: true)
            }
        }
    }

    // MARK: - Pieces

    private func planRow(_ option: PaywallPlan) -> some View {
        Button {
            plan = option
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.title).font(.body.weight(.semibold))
                    priceLabel(for: option)
                }
                Spacer()
                Image(systemName: plan == option
                      ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(plan == option ? Color.accentColor : .secondary)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(!isPlanAvailable(option))
        .accessibilityIdentifier("plan-\(option.rawValue)")
    }

    /// A price is either real or absent.
    ///
    /// The sheet used to fall back to hard-coded strings whenever RevenueCat
    /// had nothing, which meant a production offering failure rendered a
    /// polished, plausible price list wired to a Continue button that could not
    /// charge anyone. A redacted placeholder while loading, and no price at all
    /// when the store is down, is the honest version.
    @ViewBuilder
    private func priceLabel(for option: PaywallPlan) -> some View {
        if let price = subscriptions.paywallPrice(for: option) {
            Text(price.localized + suffix(for: option))
                .font(.footnote).foregroundStyle(.secondary)
        } else if subscriptions.storeState == .unavailable || subscriptions.storeState == .available {
            Text(subscriptions.storeState == .available ? "Not offered" : "Price unavailable")
                .font(.footnote).foregroundStyle(.secondary)
        } else {
            Text("Loading price")
                .font(.footnote).foregroundStyle(.secondary)
                .redacted(reason: .placeholder)
        }
    }

    private func suffix(for option: PaywallPlan) -> String {
        switch option {
        case .yearly: return " / year"
        case .monthly: return " / month"
        case .lifetime: return " once"
        }
    }

    private var unavailableCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("The App Store isn't reachable", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.semibold))
            Text("We can't load prices right now, so nothing here can be purchased. Check your connection and try again.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button("Try again") {
                Task { await subscriptions.loadOfferings() }
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("paywall-retry")
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var footer: some View {
        VStack(spacing: 8) {
            if let disclosure = purchaseDisclosure {
                Text(disclosure)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let error {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Button(action: purchase) {
                if isWorking {
                    ProgressView().frame(maxWidth: .infinity)
                } else {
                    Text(continueTitle).frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isWorking || !isStoreReady)
            .accessibilityIdentifier("paywall-continue")

            HStack(spacing: 16) {
                Button("Restore", action: restore)
                Link("Terms of Use", destination: PaywallLinks.terms)
                Link("Privacy Policy", destination: PaywallLinks.privacy)
            }
            .font(.footnote)
        }
        .padding()
        .background(.bar)
    }

    private var continueTitle: String {
        switch subscriptions.storeState {
        case .loading: return "Loading…"
        case .unavailable: return "Unavailable"
        case .available, .notConfigured:
            if plan == .lifetime { return "Buy Lifetime" }
            switch subscriptions.trialCopy(for: plan) {
            case .eligible: return "Start free trial"
            case .ineligible, .none: return "Subscribe"
            case .unknown: return "Subscribe"
            }
        }
    }

    /// Apple's introductory offer is per Apple Account and per subscription
    /// group, so a flat "7 days free" is a promise the app cannot keep for
    /// someone who has already used it.
    private var trialLine: String? {
        if plan == .lifetime {
            return "One-time purchase. Not a subscription, nothing renews."
        }
        return subscriptions.trialCopy(for: plan).text
    }

    private var purchaseDisclosure: String? {
        guard plan != .lifetime else { return trialLine }
        let period = plan == .monthly ? "monthly" : "yearly"
        let price = subscriptions.paywallPrice(for: plan)
            .map { "\($0.localized) per \(period == "monthly" ? "month" : "year")" }
            ?? "the displayed \(period) price"
        let billing: String
        switch subscriptions.trialCopy(for: plan) {
        case .eligible(let trial), .unknown(let trial):
            billing = "\(trial) Then charged \(price)."
        case .ineligible(let message):
            billing = "\(message) Charged \(price) at confirmation."
        case .none:
            billing = "Charged \(price) at confirmation."
        }
        return "\(billing) Renews \(period) until canceled. Manage or cancel in Settings > Apple Account > Subscriptions; cancel at least 24 hours before renewal."
    }

    private static let benefits = [
        "Unlimited graded balls, not 15 a day",
        "Every rally phase, including transition and defense",
        "Session history: every rally you finish, kept and scored",
        "Your missed principles ranked, so you know what to drill",
        "New positions generated forever, never a fixed question bank",
    ]

    private func isPlanAvailable(_ option: PaywallPlan) -> Bool {
        switch subscriptions.storeState {
        case .available:
            return subscriptions.package(for: option) != nil
        case .notConfigured:
            return subscriptions.paywallPrice(for: option) != nil
        case .loading, .unavailable:
            return false
        }
    }

    private func selectAvailablePlanIfNeeded() {
        guard !isPlanAvailable(plan),
              let first = PaywallPlan.allCases.first(where: isPlanAvailable)
        else { return }
        plan = first
    }

    private func purchase() {
        isWorking = true
        error = nil
        Task {
            defer { isWorking = false }
            guard await subscriptions.ensureOfferings() else {
                error = PurchaseError.productsUnavailable.errorDescription
                return
            }
            do {
                let outcome = try await subscriptions.purchase(subscriptions.package(for: plan))
                guard outcome == .purchased else { return }
                await subscriptions.confirmEntitlement()
                if subscriptions.isPro {
                    dismiss()
                } else {
                    // Apple took the money but the entitlement has not landed
                    // after the retries. Saying nothing here leaves someone who
                    // just paid staring at the sheet that charged them.
                    error = "Your purchase went through, but we couldn't confirm it yet. Tap Restore in a moment and it will unlock."
                }
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    private func restore() {
        isWorking = true
        error = nil
        Task {
            defer { isWorking = false }
            do {
                try await subscriptions.restore()
                if subscriptions.isPro {
                    dismiss()
                } else {
                    // App Review taps this button on an account with nothing to
                    // restore. A button that silently does nothing reads as
                    // broken, so say what happened.
                    error = "No previous purchase found on this Apple Account."
                }
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}
