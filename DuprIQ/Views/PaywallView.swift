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

    /// Shown only until RevenueCat's real localized price lands, so a slow
    /// network never renders an empty price row.
    var fallbackPrice: String {
        switch self {
        case .yearly: return "$59.99 / year"
        case .monthly: return "$9.99 / month"
        case .lifetime: return "$99.99 once"
        }
    }
}

struct PaywallView: View {
    @EnvironmentObject private var subscriptions: SubscriptionService
    @Environment(\.dismiss) private var dismiss

    @State private var plan: PaywallPlan = .yearly
    @State private var isWorking = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Every ball, every phase")
                        .font(.largeTitle.bold())

                    ForEach(Self.benefits, id: \.self) { benefit in
                        Label(benefit, systemImage: "checkmark.circle.fill")
                            .font(.callout)
                    }

                    ForEach(PaywallPlan.allCases) { option in
                        Button {
                            plan = option
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(option.title).font(.body.weight(.semibold))
                                    Text(subscriptions.paywallPrice(for: option)?.localized
                                         ?? option.fallbackPrice)
                                        .font(.footnote).foregroundStyle(.secondary)
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
                        .accessibilityIdentifier("plan-\(option.rawValue)")
                    }
                }
                .padding()
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    Text(plan == .lifetime
                         ? "One-time purchase. Not a subscription, nothing renews."
                         : "7 days free, then auto-renews until canceled.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

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
                            Text("Continue").frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(isWorking)
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
            .navigationTitle("DUPR IQ Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not now") { dismiss() }
                }
            }
            .task {
                await subscriptions.ensureOfferings()
                subscriptions.trackPaywallImpression(id: "main_paywall", oncePerSession: true)
            }
        }
    }

    private static let benefits = [
        "Unlimited graded balls, not 15 a day",
        "Every rally phase, including transition and defense",
        "Accuracy by phase, so you know what to drill",
        "New positions generated forever, never a fixed question bank",
    ]

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
                if subscriptions.isPro { dismiss() }
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    private func restore() {
        isWorking = true
        Task {
            defer { isWorking = false }
            try? await subscriptions.restore()
            if subscriptions.isPro { dismiss() }
        }
    }
}
