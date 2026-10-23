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

    func testExhaustedSummaryReopensAfterDayChange() {
        verifyDailyAllowanceRecovery(backgrounded: false)
    }

    func testExhaustedSummaryReopensAfterNextDayForeground() {
        verifyDailyAllowanceRecovery(backgrounded: true)
    }

    private func verifyDailyAllowanceRecovery(backgrounded: Bool) {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = [
            "-subscription.localProOverride", "NO",
            "-uitest.reset", "YES",
            "-uitest.fixture", "demo",
            "-uitest.freeLeft", "0",
            "-uitest.rolloverAfter", "15",
            "-settings.shotClock", "off",
        ]
        app.launch()
        XCTAssertTrue(app.buttons["summary-paywall"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["shot-0"].exists, "today's exhausted allowance must still hold")

        if backgrounded {
            XCUIDevice.shared.press(.home)
            app.activate()
            XCTAssertTrue(app.buttons["summary-paywall"].waitForExistence(timeout: 3))
            XCUIDevice.shared.press(.home)
            settle(16)
            app.activate()
        }

        let shot = app.buttons["shot-0"]
        XCTAssertTrue(shot.waitForExistence(timeout: 25), "a renewed allowance must reopen practice")
        XCTAssertFalse(app.buttons["summary-paywall"].exists)
        settle(1)
        shot.tap()
        XCTAssertTrue(app.buttons["next-ball"].waitForExistence(timeout: 5), "the new day's ball must be gradeable")
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

// MARK: - Motion audit walks
//
// Host-recorded with `simctl io recordVideo` so the replay can be studied
// frame by frame. Each walk picks shots in a fixed rotation, so the set covers
// right answers, wrong answers and every shot shape.
extension AuditTests {

    private func launchForMotion(seed: Int, clock: String = "off", pro: Bool = true) {
        app = XCUIApplication()
        app.launchArguments = [
            "-subscription.localProOverride", pro ? "YES" : "NO",
            "-uitest.reset", "YES",
            "-uitest.fixture", "demo",
            "-uitest.seed", String(seed),
            "-settings.shotClock", clock,
        ]
        app.launch()
        _ = app.wait(for: .runningForeground, timeout: 30)
        // A contended host can take minutes to draw the first frame; that is
        // the simulator, not the app, and must not cut a walk short.
        _ = app.buttons["shot-0"].waitForExistence(timeout: 300)
        settle(2.5)
    }

    private func tapShot(_ index: Int) -> Bool {
        let shot = app.buttons["shot-\(index)"]
        guard shot.waitForExistence(timeout: 6), shot.isHittable else { return false }
        shot.tap()
        return true
    }

    /// Sixteen balls: every option index in rotation, each replay watched in
    /// full, then replayed once more from the button.
    func testMotionWalkFullReplays() {
        walkFullReplays(seed: 5150)
    }

    /// A second court, so the set covers more shot shapes and positions.
    func testMotionWalkSecondSeed() {
        walkFullReplays(seed: 2718)
    }

    private func walkFullReplays(seed: Int) {
        launchForMotion(seed: seed)
        for ball in 0..<16 {
            if app.buttons["play-again"].exists { break }
            guard tapShot(ball % 4) else { return attachTree("motion-\(ball)") }
            settle(4.5)
            _ = tapIdentifier("replay", timeout: 3)
            settle(4.5)
            guard tapIdentifier("next-ball", timeout: 4) else { return }
            settle(1.5)
        }
    }

    /// The verdict card opened by its chevron, by a tap on the text, by a pull
    /// up, then closed by the replay button and a pull down.
    func testMotionVerdictCardExpands() {
        launchForMotion(seed: 4141)
        for ball in 0..<3 {
            guard tapShot((ball + 1) % 4) else { return attachTree("expand-\(ball)") }
            settle(3.0)
            switch ball {
            case 0:
                _ = tapIdentifier("expand-why", timeout: 3)
                settle(2.0)
                _ = tapIdentifier("replay", timeout: 3)
                settle(4.5)
            case 1:
                // Pull the header up, then back down from where it landed.
                let header = { self.app.buttons["expand-why"].firstMatch
                    .coordinate(withNormalizedOffset: CGVector(dx: -4, dy: 0.5)) }
                let low = header()
                low.press(forDuration: 0.05, thenDragTo: low.withOffset(CGVector(dx: 0, dy: -160)))
                settle(2.0)
                let high = header()
                high.press(forDuration: 0.05, thenDragTo: high.withOffset(CGVector(dx: 0, dy: 160)))
                settle(2.0)
            default:
                _ = tapIdentifier("expand-why", timeout: 3)
                settle(1.5)
                _ = tapIdentifier("expand-why", timeout: 3)
                settle(1.5)
            }
            if !tapIdentifier("next-ball", timeout: 4) { return }
            settle(1.5)
        }
    }

    /// The ways a player interrupts a replay: next mid-flight, replay mashed,
    /// Your game opened over it, the app backgrounded during it.
    func testMotionInterruptions() {
        launchForMotion(seed: 6060)
        // Next while the replay is still in the air.
        guard tapShot(1) else { return attachTree("interrupt-next") }
        settle(0.6)
        _ = tapIdentifier("next-ball", timeout: 3)
        settle(2.0)
        // Replay mashed three times.
        guard tapShot(2) else { return attachTree("interrupt-mash") }
        settle(0.8)
        for _ in 0..<3 { _ = tapIdentifier("replay", timeout: 3); settle(0.25) }
        settle(4.5)
        _ = tapIdentifier("next-ball", timeout: 3)
        settle(2.0)
        // Your game opened mid-replay, then closed.
        guard tapShot(0) else { return attachTree("interrupt-sheet") }
        settle(0.7)
        _ = tapIdentifier("your-game", timeout: 3)
        settle(2.0)
        app.buttons["Done"].firstMatch.tap()
        settle(4.0)
        _ = tapIdentifier("next-ball", timeout: 3)
        settle(2.0)
        // Backgrounded mid-replay, then resumed.
        guard tapShot(3) else { return attachTree("interrupt-background") }
        settle(0.7)
        XCUIDevice.shared.press(.home)
        settle(2.0)
        app.activate()
        settle(5.0)
        _ = tapIdentifier("replay", timeout: 3)
        settle(4.5)
    }

    /// The fast decision timer: one ball left to time out, then a quick answer.
    func testMotionShotClockTimeout() {
        launchForMotion(seed: 7070, clock: "tournament")
        settle(5.5)
        settle(4.5)
        _ = tapIdentifier("next-ball", timeout: 4)
        settle(1.0)
        _ = tapShot(2)
        settle(4.5)
    }

    /// A free player running out: the last ball, the summary, the paywall.
    func testMotionFreeLimitRun() {
        launchForMotion(seed: 8080, pro: false)
        for ball in 0..<16 {
            if app.buttons["play-again"].exists || app.buttons["summary-paywall"].exists { break }
            guard tapShot(ball % 4) else { break }
            settle(1.2)
            guard tapIdentifier("next-ball", timeout: 4) else { break }
            settle(0.8)
        }
        settle(3.0)
        _ = tapIdentifier("summary-paywall", timeout: 3)
        settle(3.0)
    }
}

private enum PracticeLimiterBalls {
    static let free = 15
}
