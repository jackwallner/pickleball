import Foundation
import RevenueCat

enum RevenueCatConfig {
    // Debug builds deliberately carry no usable key. `configureIfNeeded`
    // early-returns on the PLACEHOLDER prefix, so a simulator or agent run can
    // never reach the production project and mint fake customers in the live
    // charts. Dev testing goes through the StoreKit config plus
    // `setLocalOverride(isPro:)`.
    #if DEBUG
    static let apiKey = "PLACEHOLDER_DEBUG_NO_REVENUECAT"
    #else
    static let apiKey = "appl_FgwCPdxYFGQtaPKOJeuxwZBsrNZ"
    #endif
}

/// What actually happened at Apple's sheet. A cancel is an outcome, not an error.
enum PurchaseOutcome: Sendable {
    case purchased
    case cancelled
}

enum PurchaseError: LocalizedError {
    case productsUnavailable

    var errorDescription: String? {
        "The App Store isn't reachable right now. Check your connection and try again."
    }
}

struct PaywallPrice {
    let amount: Decimal
    let localized: String
    let locale: Locale
}

@MainActor
final class SubscriptionService: NSObject, ObservableObject {
    static let shared = SubscriptionService()

    @Published private(set) var isPro = false
    @Published private(set) var offerings: Offerings?

    private var isConfigured = false
    private let localOverrideKey = "subscription.localProOverride"
    private var paywallImpressionsThisSession: Set<String> = []

    override private init() {
        super.init()
        isPro = UserDefaults.standard.bool(forKey: localOverrideKey)
    }

    func start() {
        configureIfNeeded()
        guard isConfigured else { return }
        Task {
            await refreshCustomerInfo()
            await loadOfferings()
        }
    }

    /// Dev/testing switch: flips Pro without a live RC key (Settings toggle).
    func setLocalOverride(isPro: Bool) {
        UserDefaults.standard.set(isPro, forKey: localOverrideKey)
        self.isPro = isPro
    }

    private func configureIfNeeded() {
        guard !isConfigured else { return }
        #if targetEnvironment(simulator)
        guard RevenueCatConfig.apiKey.hasPrefix("test_") else { return }
        #endif
        guard !RevenueCatConfig.apiKey.contains("PLACEHOLDER") else { return }
        #if DEBUG
        Purchases.logLevel = .debug
        #endif
        Purchases.configure(withAPIKey: RevenueCatConfig.apiKey)
        Purchases.shared.delegate = self
        isConfigured = true
    }

    /// Feeds RevenueCat's `paywall_encounter_v3`. A custom paywall emits no
    /// events of its own, so without this call everything between "installed"
    /// and "started a trial" is invisible for this app.
    func trackPaywallImpression(id: String, oncePerSession: Bool = false) {
        guard isConfigured else { return }
        if oncePerSession {
            guard !paywallImpressionsThisSession.contains(id) else { return }
            paywallImpressionsThisSession.insert(id)
        }
        Purchases.shared.trackCustomPaywallImpression(
            CustomPaywallImpressionParams(paywallId: id)
        )
    }

    func refreshCustomerInfo() async {
        guard isConfigured else { return }
        if let info = try? await Purchases.shared.customerInfo() {
            apply(info)
        }
    }

    func loadOfferings() async {
        guard isConfigured else { return }
        offerings = try? await Purchases.shared.offerings()
    }

    func package(for plan: PaywallPlan) -> Package? {
        guard let offering = offerings?.current else { return nil }
        switch plan {
        case .yearly: return offering.annual
        case .monthly: return offering.monthly
        case .lifetime: return offering.lifetime
        }
    }

    func paywallPrice(for plan: PaywallPlan) -> PaywallPrice? {
        guard let product = package(for: plan)?.storeProduct else { return nil }
        return PaywallPrice(
            amount: product.price,
            localized: product.localizedPriceString,
            locale: product.priceFormatter?.locale ?? .current
        )
    }

    /// Offerings can still be in flight when a player reaches the trial CTA on
    /// a cold, slow network. Give them one more chance to land before we call
    /// the products missing, so the button isn't dead on a fast tapper.
    @discardableResult
    func ensureOfferings() async -> Bool {
        guard isConfigured else { return false }
        if offerings?.current != nil { return true }
        await loadOfferings()
        return offerings?.current != nil
    }

    func purchase(_ package: Package?) async throws -> PurchaseOutcome {
        guard isConfigured else {
            throw PurchaseError.productsUnavailable
        }
        guard let package else { throw PurchaseError.productsUnavailable }
        let result = try await Purchases.shared.purchase(package: package)
        // RevenueCat reports a user backing out of Apple's sheet as a normal
        // result, not an error. Treating it as a failure is what used to shove
        // a second paywall in front of someone who just said "not now".
        if result.userCancelled { return .cancelled }
        apply(result.customerInfo)
        return .purchased
    }

    /// StoreKit says the money moved; RevenueCat's entitlement can take a beat
    /// to catch up. Poll briefly rather than leave someone who just paid
    /// staring at the paywall that took their money.
    @discardableResult
    func confirmEntitlement(attempts: Int = 3) async -> Bool {
        guard isConfigured else { return isPro }
        for attempt in 0..<attempts {
            await refreshCustomerInfo()
            if isPro { return true }
            if attempt < attempts - 1 {
                try? await Task.sleep(nanoseconds: 1_200_000_000)
            }
        }
        return isPro
    }

    func restore() async throws {
        guard isConfigured else { return }
        let info = try await Purchases.shared.restorePurchases()
        apply(info)
    }

    private func apply(_ info: CustomerInfo) {
        let entitled = info.entitlements["pro"]?.isActive == true
        let override = UserDefaults.standard.bool(forKey: localOverrideKey)
        isPro = entitled || override
    }
}

extension SubscriptionService: PurchasesDelegate {
    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            self.apply(customerInfo)
        }
    }
}
