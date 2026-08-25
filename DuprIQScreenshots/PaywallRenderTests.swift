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
///
/// Like `ScreenshotTests`, this never calls XCTFail on a missing element: a
/// failing UI test spends ten minutes collecting simulator diagnostics before
/// it tells you anything.
@MainActor
final class PaywallRenderTests: XCTestCase {
    private var app: XCUIApplication!
    private var problems: [String] = []

    override func setUp() {
        continueAfterFailure = true
        app = XCUIApplication()
    }

    override func tearDown() {
        guard !problems.isEmpty else { return }
        let note = XCTAttachment(string: problems.joined(separator: "\n"))
        note.name = "problems"
        note.lifetime = .keepAlways
        add(note)
    }

    /// The paywall, reached the way Settings reaches it. Settings' "See Pro"
    /// row is the stable entry point; the drill-session route needs the free
    /// daily allowance to be exhausted first.
    func testPaywallPlanCards() {
        launch()
        settle()

        guard openSettingsTab(), tapSeePro() else {
            problems.append("could not open the paywall")
            attachTree("paywall_missing")
            return
        }
        settle(2.5)
        capture("paywall_plans")
        attachTree("paywall")
    }

    // MARK: - Helpers

    private func launch() {
        // Start from a clean free account: the local Pro override is what the
        // Settings toggle flips, and a leftover YES hides the paywall entirely.
        app.launchArguments = ["-subscription.localProOverride", "NO"]
        app.launch()
        _ = app.wait(for: .runningForeground, timeout: 30)
    }

    private func openSettingsTab() -> Bool {
        let tab = app.tabBars.buttons["Settings"].firstMatch
        guard tab.waitForExistence(timeout: 8) else { return false }
        tab.tap()
        settle(1.0)
        return true
    }

    private func tapSeePro() -> Bool {
        let button = app.buttons["See Pro"].firstMatch
        guard button.waitForExistence(timeout: 4) else { return false }
        button.tap()
        return true
    }

    private func settle(_ seconds: TimeInterval = 1.6) {
        Thread.sleep(forTimeInterval: seconds)
    }

    private func capture(_ name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func attachTree(_ name: String) {
        let tree = XCTAttachment(string: app.debugDescription)
        tree.name = "tree_\(name)"
        tree.lifetime = .keepAlways
        add(tree)
    }
}
