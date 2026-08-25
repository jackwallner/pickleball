import XCTest

/// Renders the purchase surface so its real prices can be read off a
/// screenshot instead of guessed at.
///
/// This has to be a UI test. `SubscriptionService` never configures RevenueCat
/// on a simulator (a prod key there fabricates customers in the live charts),
/// so a plain `simctl launch` can only ever show the paywall's empty state. The
/// DEBUG-only bridge reads display values from the bundled `.storekit` catalog
/// and hands them to the shipping paywall view, which therefore renders
/// unmodified without creating a RevenueCat customer.
///
/// Run: scripts/capture-paywall.sh <udid> <out-dir>
@MainActor
final class PaywallRenderTests: ScreenshotHarness {

    /// The paywall, reached the way Settings reaches it. Settings' "See Pro"
    /// row is the stable entry point; the drill-session route needs the free
    /// daily allowance to be exhausted first.
    func testPaywallPlanCards() {
        launch()
        guard selectTab("Settings") else { return }
        settle(1.0)
        let seePro = app.buttons["See Pro"].firstMatch
        guard seePro.waitForExistence(timeout: 4) else {
            report("could not open the paywall")
            attachTree("paywall_missing")
            return
        }
        seePro.tap()
        settle(2.5)
        // A price row that rendered its redacted placeholder is not a paywall
        // screenshot, and it used to be indistinguishable from a real one.
        expect("plan-yearly", on: "paywall")
        expect("paywall-continue", on: "paywall")
        capture("paywall_plans")
        attachTree("paywall")
    }
}
