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

    /// Where the sheet was opened from, which becomes the impression id's
    /// surface in `ConversionDiagnostics`.
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
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Play every ball")
                            .font(Theme.display(34))
                            .foregroundStyle(Theme.ink)
                        Text("Free gives you \(PracticeLimiter.freeDailyBalls) balls a day. Pro takes the limit off and shows you what is costing you points.")
                            .font(.callout)
                            .foregroundStyle(Theme.inkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Self.benefits, id: \.title) { benefit in
                            HStack(alignment: .top, spacing: 14) {
                                Image(systemName: benefit.icon)
                                    .font(.headline)
                                    .foregroundStyle(Theme.Surface.ball)
                                    .frame(width: 26)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(benefit.title)
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(Theme.ink)
                                    Text(benefit.detail)
                                        .font(.footnote)
                                        .foregroundStyle(Theme.inkSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }

                    if subscriptions.storeState == .unavailable {
                        unavailableCard
                    }

                    VStack(spacing: 10) {
                        ForEach(PaywallPlan.allCases) { option in
                            planRow(option)
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: Theme.readableContentWidth)
                .frame(maxWidth: .infinity)
            }
            .background(Theme.background.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                footer
            }
            .navigationTitle(AppBrand.proName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not now") { dismiss() }
                }
            }
            .task {
                await subscriptions.ensureOfferings()
                selectAvailablePlanIfNeeded()
                subscriptions.trackPaywallImpression(id: "dupriq_\(source)_paywall", oncePerSession: true)
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Pieces

    private func planRow(_ option: PaywallPlan) -> some View {
        let selected = plan == option
        return Button {
            plan = option
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                    priceLabel(for: option)
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(selected ? Theme.Surface.ball : Theme.inkTertiary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(selected ? Theme.court.opacity(0.35) : Theme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(selected ? Theme.courtLight : Theme.rule, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(!isPlanAvailable(option))
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("plan-\(option.rawValue)")
    }

    /// A price is either real or absent. A redacted placeholder while loading,
    /// and no price at all when the store is down.
    @ViewBuilder
    private func priceLabel(for option: PaywallPlan) -> some View {
        if let price = subscriptions.paywallPrice(for: option) {
            Text(price.localized + suffix(for: option))
                .font(.footnote).foregroundStyle(Theme.inkSecondary)
        } else if subscriptions.storeState == .unavailable || subscriptions.storeState == .available {
            Text(subscriptions.storeState == .available ? "Not offered" : "Price unavailable")
                .font(.footnote).foregroundStyle(Theme.inkSecondary)
        } else {
            Text("Loading price")
                .font(.footnote).foregroundStyle(Theme.inkSecondary)
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
                .foregroundStyle(Theme.ink)
            Text("We can't load prices right now, so nothing here can be purchased. Check your connection and try again.")
                .font(.footnote)
                .foregroundStyle(Theme.inkSecondary)
            Button("Try again") {
                Task { await subscriptions.loadOfferings() }
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("paywall-retry")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var footer: some View {
        VStack(spacing: 8) {
            if let disclosure = purchaseDisclosure {
                Text(disclosure)
                    .font(.caption2)
                    .foregroundStyle(Theme.inkSecondary)
                    .multilineTextAlignment(.center)
            }

            if let error {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(Theme.wrongRed)
                    .multilineTextAlignment(.center)
            }

            // The links sit above the button so it lands exactly where the
            // summary's "See Pro" was: same inset, same bottom margin.
            HStack(spacing: 16) {
                Button("Restore", action: restore)
                Link("Terms of Use", destination: PaywallLinks.terms)
                Link("Privacy Policy", destination: PaywallLinks.privacy)
            }
            .font(.footnote)
            .tint(Theme.courtLight)

            Button(action: purchase) {
                Group {
                    if isWorking {
                        ProgressView().tint(.white)
                    } else {
                        Text(continueTitle)
                    }
                }
                .primaryCTA(color: isStoreReady ? Theme.court : Theme.card)
            }
            .buttonStyle(PressableCTAStyle())
            .disabled(isWorking || !isStoreReady)
            .accessibilityIdentifier("paywall-continue")
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 24)
        .frame(maxWidth: Theme.readableContentWidth)
        .frame(maxWidth: .infinity)
        .background(
            Theme.background
                .overlay(alignment: .top) { Rectangle().fill(Theme.rule).frame(height: 1) }
                .ignoresSafeArea(edges: .bottom)
        )
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

    private struct Benefit {
        let icon: String
        let title: String
        let detail: String
    }

    private static let benefits = [
        Benefit(icon: "infinity", title: "Unlimited balls",
                detail: "As many runs a day as you want."),
        Benefit(icon: "scope", title: "Your traps, ranked",
                detail: "The tempting wrong shots costing you the most points."),
        Benefit(icon: "clock.arrow.circlepath", title: "Every run kept",
                detail: "Score and right calls for every run you play."),
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
