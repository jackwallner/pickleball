import XCTest

/// The paywall in isolation, with the StoreKit catalog attached so the plan
/// rows render real prices on a simulator (RevenueCat is never configured on
/// one, so a plain `simctl launch` can only show the empty state).
@MainActor
final class PaywallRenderTests: ScreenshotHarness {

    func testPaywallPlanCards() {
        launch()
        guard tapIdentifier("your-game") else { return attachTree("paywall_missing") }
        settle(1.0)
        guard tapIdentifier("your-game-pro") else { return attachTree("paywall_missing") }
        settle(2.5)
        // A price row that rendered its redacted placeholder is not a paywall
        // screenshot, and it used to be indistinguishable from a real one.
        expect("plan-yearly", on: "paywall")
        expect("paywall-continue", on: "paywall")
        capture("paywall_plans")
        attachTree("paywall")
    }
}
