import XCTest

/// The release gate's journeys: what a player sees on the way to deciding the
/// app is worth keeping. Each step ends in a `QA.checkpoint`, which runs the
/// fleet oracles (late layout shifts, clipped or overlapping text, off-screen
/// controls, copy that leaks a value or a dash, Apple's accessibility audit, a
/// screen that never stops drawing). `qa-gate run ~/pickleball` runs this class
/// once per persona and turns the findings into a verdict.
///
/// Journeys assert reachability only; judging the screen is the oracles' job.
@MainActor
final class ReleaseJourneysUITests: XCTestCase {

    /// A brand-new player: three onboarding steps, then the first ball.
    func testFirstRunOnboardingToFirstBall() {
        let app = launch(["-uitest.reset", "YES", "-subscription.localProOverride", "NO"])
        let next = app.buttons["onboarding-continue"]
        XCTAssertTrue(next.waitForExistence(timeout: 120), "onboarding never rendered")
        QA.checkpoint(app, "onboarding-court")

        next.tap()
        XCTAssertTrue(app.buttons["level-rec"].waitForExistence(timeout: 10), "level step missing")
        QA.checkpoint(app, "onboarding-level")
        app.buttons["level-rec"].tap()
        next.tap()

        XCTAssertTrue(app.buttons["half-either"].waitForExistence(timeout: 10), "side step missing")
        QA.checkpoint(app, "onboarding-side")
        app.buttons["half-either"].tap()
        next.tap()

        XCTAssertTrue(app.buttons["shot-0"].waitForExistence(timeout: 60), "first ball never appeared")
        QA.checkpoint(app, "first-ball")
    }

    /// The core loop: read, pick, watch the replay, open the why, next ball.
    func testPickReplayExplainAndNext() {
        let app = launchCourt(pro: true)
        QA.checkpoint(app, "deciding")

        app.buttons["shot-1"].tap()
        XCTAssertTrue(app.buttons["next-ball"].waitForExistence(timeout: 10), "no verdict after a pick")
        QA.checkpoint(app, "graded", grace: 4.5)

        app.buttons["expand-why"].tap()
        QA.checkpoint(app, "explanation-open")

        app.buttons["replay"].tap()
        QA.checkpoint(app, "replay", grace: 4.5)

        app.buttons["next-ball"].tap()
        XCTAssertTrue(app.buttons["shot-0"].waitForExistence(timeout: 10), "next ball never appeared")
        QA.checkpoint(app, "next-ball")
    }

    /// Your game, its upgrade, and Settings, from the court.
    func testYourGameUpgradeAndSettings() {
        let app = launchCourt(pro: false)
        app.buttons["your-game"].tap()
        XCTAssertTrue(app.buttons["your-game-done"].waitForExistence(timeout: 10), "Your game never opened")
        QA.checkpoint(app, "your-game")

        let upgrade = app.buttons["your-game-pro"].firstMatch
        if upgrade.waitForExistence(timeout: 5) {
            upgrade.tap()
            QA.checkpoint(app, "paywall", grace: 2)
            dismissSheet(app)
        }

        app.buttons["open-settings"].tap()
        XCTAssertTrue(app.buttons["settings-timer"].waitForExistence(timeout: 10), "Settings never opened")
        QA.checkpoint(app, "settings")
    }

    /// The last free ball of the day, the summary it ends on, and the paywall.
    func testDailyLimitSummaryAndPaywall() {
        let app = launchCourt(pro: false, extra: ["-uitest.freeLeft", "1"])
        app.buttons["shot-0"].tap()
        XCTAssertTrue(app.buttons["next-ball"].waitForExistence(timeout: 10), "no verdict on the last ball")
        app.buttons["next-ball"].tap()
        XCTAssertTrue(app.buttons["summary-paywall"].waitForExistence(timeout: 10), "daily-limit summary missing")
        QA.checkpoint(app, "daily-limit")

        app.buttons["summary-paywall"].tap()
        QA.checkpoint(app, "paywall", grace: 2)
        dismissSheet(app)
        QA.checkpoint(app, "daily-limit-return")
    }

    /// Backgrounded mid-replay, then killed: the court has to come back whole.
    func testInterruptedAndRelaunched() {
        let app = launchCourt(pro: true)
        app.buttons["shot-2"].tap()
        XCTAssertTrue(app.buttons["next-ball"].waitForExistence(timeout: 10))
        QA.interrupt(app)
        QA.checkpoint(app, "after-background", grace: 4.5)
        QA.relaunch(app)
        XCTAssertTrue(app.buttons["shot-0"].waitForExistence(timeout: 120), "court missing after relaunch")
        QA.checkpoint(app, "after-relaunch")
    }

    // MARK: - Helpers

    private func launch(_ arguments: [String], journey: String = #function) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        QA.launch(app, arguments: arguments, journey: journey)
        return app
    }

    /// The demo history and a pinned seed, so every persona sees the same court.
    private func launchCourt(pro: Bool, extra: [String] = [], journey: String = #function) -> XCUIApplication {
        let app = launch([
            "-uitest.fixture", "demo", "-uitest.seed", "5150",
            "-subscription.localProOverride", pro ? "YES" : "NO",
            "-settings.shotClock", "off",
        ] + extra, journey: journey)
        XCTAssertTrue(app.buttons["shot-0"].waitForExistence(timeout: 120), "court never rendered")
        return app
    }

    private func dismissSheet(_ app: XCUIApplication) {
        for label in ["Close", "Not now", "Done", "Cancel"] {
            let button = app.buttons[label].firstMatch
            if button.exists, button.isHittable { button.tap(); break }
        }
        sleep(1)
    }
}
