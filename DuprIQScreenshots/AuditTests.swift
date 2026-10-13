import XCTest

/// Not part of the App Store set. This walks the real drill loop slowly enough
/// that a host-side frame grabber can record what the player actually sees, so
/// the first-person court can be audited as an experience rather than as a
/// pile of unit tests that all pass.
@MainActor
final class AuditTests: ScreenshotHarness {

    func testFirstRunCTAsAndUntimedCourtStayInteractive() {
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
        XCTAssertGreaterThanOrEqual(continueButton.frame.width, 300)
        continueButton.tap()

        XCTAssertTrue(app.buttons["onboarding-level-new"].waitForExistence(timeout: 4))
        app.buttons["onboarding-continue"].tap()
        XCTAssertTrue(app.staticTexts["onboarding-level-required"].waitForExistence(timeout: 3))
        app.buttons["onboarding-level-new"].tap()
        app.buttons["onboarding-continue"].tap()

        let startButton = app.buttons["onboarding-continue"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 4))
        XCTAssertEqual(startButton.label, "Start practising")
        XCTAssertGreaterThanOrEqual(startButton.frame.height, 54)
        startButton.tap()

        let primerButton = app.buttons["primer-done"]
        XCTAssertTrue(primerButton.waitForExistence(timeout: 5))
        XCTAssertTrue(primerButton.isHittable)
        primerButton.tap()

        let mixedRally = app.buttons["mixed-rally"]
        XCTAssertTrue(mixedRally.waitForExistence(timeout: 5))
        mixedRally.tap()
        settle(6.0)

        let firstShot = app.buttons["shot-0"]
        XCTAssertTrue(firstShot.exists)
        XCTAssertTrue(firstShot.isHittable, "an untimed beginner court must remain playable")
        firstShot.tap()

        let nextButton = app.buttons["next-ball"]
        XCTAssertTrue(nextButton.waitForExistence(timeout: 5))
        XCTAssertTrue(nextButton.isHittable)
        XCTAssertGreaterThanOrEqual(nextButton.frame.height, 54)
        XCTAssertGreaterThanOrEqual(nextButton.frame.width, 300)
        nextButton.tap()

        XCTAssertTrue(app.buttons["shot-0"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["shot-0"].isHittable)
    }

    private func launchForAudit(seed: Int) {
        app = XCUIApplication()
        app.launchArguments = [
            "-subscription.localProOverride", "YES",
            "-uitest.reset", "YES",
            "-uitest.skipPrimer", "YES",
            "-uitest.seed", String(seed),
            "-settings.shotClock", "off",
        ]
        app.launch()
        _ = app.wait(for: .runningForeground, timeout: 30)
        settle(2.0)
    }

    /// Walk a mixed rally, pausing on every question and every verdict.
    func testWalkTheRally() {
        launchForAudit(seed: 4242)
        guard selectTab("Practice") else { return }
        guard tapIdentifier("mixed-rally") else { return attachTree("audit") }

        for ball in 0..<10 {
            if app.buttons["session-done"].exists { break }
            settle(2.4)
            guard tapFirstOption() else {
                capture("audit_walk_pick_\(ball)")
                attachTree("walk_pick_\(ball)")
                break
            }
            settle(2.2)
            guard tapIdentifier("next-ball", timeout: 4) else {
                attachTree("ball\(ball)_next")
                break
            }
        }
        settle(2.0)
    }

    /// The two Pro modes that render content INSIDE a session runner rather
    /// than full bleed. Timed Challenge uses the generated court; Match
    /// Warm-Up intentionally remains an authored text-choice session.
    func testEmbeddedCourtModes() {
        for tile in ["tile-timed", "tile-warmup"] {
            launchForAudit(seed: 909)
            guard selectTab("Practice") else { return }
            guard tapIdentifier(tile) else {
                attachTree(tile)
                continue
            }
            settle(3.4)
            if !tapFirstOption() {
                capture("audit_embedded_pick_\(tile)")
                attachTree("embedded_pick_\(tile)")
            }
            settle(3.0)
            app.terminate()
        }
    }

    /// One question per phase, held long enough to read the framing.
    func testEveryPhase() {
        for phase in ["serveReturn", "thirdShot", "transition", "dinkRally", "attack", "defense"] {
            launchForAudit(seed: 909)
            guard selectTab("Practice") else { return }
            guard tapIdentifier("court-\(phase)") else {
                attachTree("phase-\(phase)")
                continue
            }
            settle(3.0)
            capture("audit_question_\(phase)")
            if tapFirstOption() {
                settle(2.4)
                capture("audit_graded_\(phase)")
            }
            app.terminate()
        }
    }
}
