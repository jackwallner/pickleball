import XCTest

/// Not part of the App Store set. This walks the real drill loop slowly enough
/// that a host-side frame grabber can record what the player actually sees, so
/// the first-person court can be audited as an experience rather than as a
/// pile of unit tests that all pass.
@MainActor
final class AuditTests: ScreenshotHarness {

    func testFirstRunGoesStraightToAPlayableCourt() {
        app = XCUIApplication()
        app.launchArguments = [
            "-subscription.localProOverride", "NO",
            "-uitest.reset", "YES",
            "-uitest.seed", "4242",
        ]
        app.launch()
        _ = app.wait(for: .runningForeground, timeout: 30)

        let continueButton = app.buttons["onboarding-continue"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 8))
        XCTAssertTrue(continueButton.isHittable)
        XCTAssertGreaterThanOrEqual(continueButton.frame.height, 54)
        continueButton.tap()

        XCTAssertTrue(app.buttons["level-new"].waitForExistence(timeout: 4))
        XCTAssertFalse(app.buttons["onboarding-continue"].isEnabled, "a level has to be picked")
        app.buttons["level-new"].tap()
        app.buttons["onboarding-continue"].tap()

        XCTAssertTrue(app.buttons["half-left"].waitForExistence(timeout: 4))
        app.buttons["half-left"].tap()
        app.buttons["onboarding-continue"].tap()

        let firstShot = app.buttons["shot-0"]
        XCTAssertTrue(firstShot.waitForExistence(timeout: 8), "onboarding ends on the court, not a lobby")
        XCTAssertTrue(firstShot.isHittable)
        firstShot.tap()

        XCTAssertTrue(app.buttons["replay"].waitForExistence(timeout: 5))
        let nextButton = app.buttons["next-ball"]
        XCTAssertTrue(nextButton.isHittable)
        XCTAssertGreaterThanOrEqual(nextButton.frame.height, 54)
        nextButton.tap()

        XCTAssertTrue(app.buttons["shot-0"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["shot-0"].isHittable)
    }

    /// Plays a whole free day: every ball is gradeable, focus balls appear,
    /// and the run ends on the summary rather than mid-point.
    func testAFullRunEndsOnTheSummary() {
        launchForAudit(seed: 909)
        var sawFocus = false
        for _ in 0..<PracticeLimiterBalls.free {
            if app.buttons["play-again"].exists || app.buttons["summary-paywall"].exists { break }
            guard app.buttons["shot-0"].waitForExistence(timeout: 6) else { break }
            if app.descendants(matching: .any)["focus-ball"].exists { sawFocus = true }
            app.buttons["shot-0"].tap()
            guard app.buttons["next-ball"].waitForExistence(timeout: 4) else {
                return XCTFail("a graded ball had no next button")
            }
            app.buttons["next-ball"].tap()
        }
        XCTAssertTrue(sawFocus, "a run of points should include a focus ball")
        XCTAssertTrue(
            app.buttons["play-again"].waitForExistence(timeout: 5)
                || app.buttons["summary-paywall"].exists,
            "the run should end on the summary"
        )
    }

    private func launchForAudit(seed: Int) {
        app = XCUIApplication()
        app.launchArguments = [
            "-subscription.localProOverride", "YES",
            "-uitest.reset", "YES",
            "-uitest.fixture", "demo",
            "-uitest.seed", String(seed),
            "-settings.shotClock", "off",
        ]
        app.launch()
        _ = app.wait(for: .runningForeground, timeout: 30)
        settle(2.0)
    }

    // Frame-grab walk used by the court audits.
    func testWalkTwelveBallsForFrameCapture() {
        launchForAudit(seed: 4242)
        settle(3.0)
        for _ in 0..<12 {
            guard tapFirstOption() else { return attachTree("audit") }
            settle(3.6)
            guard tapIdentifier("next-ball", timeout: 4) else { return }
            settle(2.0)
        }
    }
}

private enum PracticeLimiterBalls {
    static let free = 15
}
