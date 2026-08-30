import Foundation
import RevenueCat
import StoreKit

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

/// Whether the paywall has real, purchasable products to show.
///
/// The paywall used to render plausible prices whichever way this went, which
/// is fine for a screenshot and dishonest on a customer's phone: a polished
/// price list attached to a Continue button that cannot charge anyone reads as
/// a broken app, not as a network problem. These states are what the sheet
/// renders instead of guessing.
enum StoreState: Equatable, Sendable {
    /// Offerings are in flight. Prices are redacted, Continue is disabled.
    case loading
    /// A current offering with at least one package arrived.
    case available
    /// RevenueCat is configured but produced nothing purchasable.
    case unavailable
    /// RevenueCat is deliberately not configured: a simulator, or a DEBUG
    /// build carrying the placeholder key. DEBUG catalog prices stand in.
    case notConfigured
}

/// What the trial line under the Continue button is allowed to claim.
///
/// Apple's introductory offer is per Apple Account and per subscription group,
/// so "7 days free" is not a property of the product, it is a property of the
/// person reading it.
enum TrialCopy: Equatable, Sendable {
    case eligible(String)
    case ineligible(String)
    case unknown(String)
    case none

    var text: String? {
        switch self {
        case .eligible(let value), .ineligible(let value), .unknown(let value): return value
        case .none: return nil
        }
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
    @Published private(set) var storeState: StoreState = .loading
    /// Intro-offer eligibility per product id, as RevenueCat reports it.
    @Published private(set) var introEligibility: [String: IntroEligibilityStatus] = [:]

    private var isConfigured = false
    private let localOverrideKey = "subscription.localProOverride"
    private var paywallImpressionsThisSession: Set<String> = []
    /// DEBUG StoreKit Testing catalog prices. Used when RevenueCat is not
    /// configured (simulator / placeholder key) so the paywall can still
    /// render the three packages without minting a production customer.
    #if DEBUG
    @Published private var storeKitPrices: [PaywallPlan: PaywallPrice] = [:]

    private static let storeKitProductIDs: [PaywallPlan: String] = [
        .monthly: "com.jackwallner.pickleball.pro.monthly",
        .yearly: "com.jackwallner.pickleball.pro.yearly",
        .lifetime: "com.jackwallner.pickleball.pro.lifetime",
    ]
    #endif

    override private init() {
        super.init()
        isPro = UserDefaults.standard.bool(forKey: localOverrideKey)
    }

    func start() {
        configureIfNeeded()
        #if DEBUG
        if storeKitPrices.isEmpty {
            storeKitPrices = Self.pricesFromStoreKitCatalog()
        }
        #endif
        guard isConfigured else {
            storeState = .notConfigured
            Task { await loadStoreKitPricesIfNeeded() }
            return
        }
        Task {
            await loadStoreKitPricesIfNeeded()
            await refreshCustomerInfo()
            await loadOfferings()
        }
    }

    /// A purchase or a cancellation can happen entirely outside the app: in
    /// Settings, on another device, or in the App Store's own subscription
    /// management. Without a foreground refresh the gate stays stale until the
    /// delegate happens to fire, which is how a paying customer ends up
    /// looking at a paywall.
    func refreshOnForeground() {
        guard isConfigured else { return }
        Task {
            await refreshCustomerInfo()
            if offerings?.current == nil { await loadOfferings() }
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
        guard isConfigured else {
            storeState = .notConfigured
            return
        }
        storeState = .loading
        offerings = try? await Purchases.shared.offerings()
        let packages = offerings?.current?.availablePackages ?? []
        storeState = packages.isEmpty ? .unavailable : .available
        await loadIntroEligibility(for: packages)
    }

    /// Ask RevenueCat which of the subscription products this Apple Account can
    /// still start a trial on. A failure leaves the map empty, which the
    /// paywall renders as the qualified "new subscribers" wording rather than
    /// as a promise.
    private func loadIntroEligibility(for packages: [Package]) async {
        guard isConfigured, !packages.isEmpty else { return }
        let result = await Purchases.shared.checkTrialOrIntroDiscountEligibility(
            packages: packages
        )
        var next: [String: IntroEligibilityStatus] = [:]
        for (package, eligibility) in result {
            next[package.storeProduct.productIdentifier] = eligibility.status
        }
        introEligibility = next
    }

    /// The honest trial line for a plan, given the product's real offer and
    /// this account's real eligibility.
    func trialCopy(for plan: PaywallPlan) -> TrialCopy {
        guard plan != .lifetime else { return .none }
        guard let product = package(for: plan)?.storeProduct else {
            // No product in hand yet: say the thing that is true for everyone.
            return .unknown("7 days free for new subscribers.")
        }
        guard let intro = product.introductoryDiscount else {
            return .none
        }
        let period = Self.periodDescription(intro)
        switch introEligibility[product.productIdentifier] {
        case .eligible:
            return .eligible("\(period) free for eligible new subscribers.")
        case .ineligible:
            return .ineligible("You've already used your free trial.")
        default:
            return .unknown("\(period) free for new subscribers.")
        }
    }

    private static func periodDescription(_ discount: StoreProductDiscount) -> String {
        let period = discount.subscriptionPeriod
        let count = period.value * discount.numberOfPeriods
        switch period.unit {
        case .day: return count == 1 ? "1 day" : "\(count) days"
        case .week: return count == 1 ? "7 days" : "\(count) weeks"
        case .month: return count == 1 ? "1 month" : "\(count) months"
        case .year: return count == 1 ? "1 year" : "\(count) years"
        @unknown default: return "A free trial"
        }
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
        if let product = package(for: plan)?.storeProduct {
            return PaywallPrice(
                amount: product.price,
                localized: product.localizedPriceString,
                locale: product.priceFormatter?.locale ?? .current
            )
        }
        #if DEBUG
        return storeKitPrices[plan]
        #else
        return nil
        #endif
    }

    /// Reads display prices from the bundled StoreKit Testing catalog so a
    /// simulator UI test can render the three plan cards without configuring
    /// the production RevenueCat key. `Product.products` is empty unless
    /// StoreKit Testing is actually attached, which xcodebuild does not do
    /// reliably, so the bundled `.storekit` file is the source of truth.
    private func loadStoreKitPricesIfNeeded() async {
        #if DEBUG
        var next = Self.pricesFromStoreKitCatalog()
        let ids = Array(Self.storeKitProductIDs.values)
        if let products = try? await Product.products(for: ids), !products.isEmpty {
            for (plan, id) in Self.storeKitProductIDs {
                guard let product = products.first(where: { $0.id == id }) else { continue }
                next[plan] = PaywallPrice(
                    amount: product.price,
                    localized: product.displayPrice,
                    locale: Locale.current
                )
            }
        }
        storeKitPrices = next
        #endif
    }

    #if DEBUG
    /// Parses `DuprIQ.storekit` from the app bundle. Falls back to the
    /// catalog's listed USD amounts if the file is missing at runtime.
    private static func pricesFromStoreKitCatalog() -> [PaywallPlan: PaywallPrice] {
        let locale = Locale(identifier: "en_US")
        func formatted(_ amount: Decimal) -> PaywallPrice {
            let fmt = NumberFormatter()
            fmt.numberStyle = .currency
            fmt.locale = locale
            let text = fmt.string(from: amount as NSDecimalNumber) ?? "\(amount)"
            return PaywallPrice(amount: amount, localized: text, locale: locale)
        }

        var amounts: [PaywallPlan: Decimal] = [
            .monthly: Decimal(string: "9.99")!,
            .yearly: Decimal(string: "59.99")!,
            .lifetime: Decimal(string: "99.99")!,
        ]

        if let url = Bundle.main.url(forResource: "DuprIQ", withExtension: "storekit"),
           let data = try? Data(contentsOf: url),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            func ingest(_ productID: String, _ displayPrice: String) {
                guard let plan = storeKitProductIDs.first(where: { $0.value == productID })?.key,
                      let amount = Decimal(string: displayPrice)
                else { return }
                amounts[plan] = amount
            }
            for product in json["products"] as? [[String: Any]] ?? [] {
                if let id = product["productID"] as? String,
                   let price = product["displayPrice"] as? String {
                    ingest(id, price)
                }
            }
            for group in json["subscriptionGroups"] as? [[String: Any]] ?? [] {
                for sub in group["subscriptions"] as? [[String: Any]] ?? [] {
                    if let id = sub["productID"] as? String,
                       let price = sub["displayPrice"] as? String {
                        ingest(id, price)
                    }
                }
            }
        }

        return amounts.mapValues(formatted)
    }
    #endif

    /// Offerings can still be in flight when a player reaches the trial CTA on
    /// a cold, slow network. Give them one more chance to land before we call
    /// the products missing, so the button isn't dead on a fast tapper.
    @discardableResult
    func ensureOfferings() async -> Bool {
        guard isConfigured else {
            storeState = .notConfigured
            return false
        }
        if offerings?.current?.availablePackages.isEmpty == false {
            storeState = .available
            return true
        }
        await loadOfferings()
        return storeState == .available
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
