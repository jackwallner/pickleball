import XCTest

/// Persona audit: a first-time player who does not know pickleball vocabulary
/// and wants one useful result immediately. Not part of the App Store set.
///
/// Every step attaches a screenshot and the elapsed seconds since launch, so a
/// reviewer can judge how long the path to a first graded answer really is.
/// Nothing here asserts product quality; it records what is on screen.
@MainActor
final class NewcomerAuditTests: ScreenshotHarness {
    private var started = Date()
    nonisolated(unsafe) private var notes: [String] = []

    private func launchFresh() {
        app = XCUIApplication()
        app.launchArguments = [
            "-subscription.localProOverride", "NO",
            "-uitest.reset", "YES",
            "-uitest.seed", "4242",
            "-settings.shotClock", "off",
        ]
        app.launch()
        _ = app.wait(for: .runningForeground, timeout: 30)
        started = Date()
    }

    private func shot(_ name: String, settle seconds: TimeInterval = 1.2) {
        settle(seconds)
        capture(name)
        note("t=\(Int(Date().timeIntervalSince(started)))s \(name)")
    }

    private func note(_ line: String) { notes.append(line) }

    private func frameNote(_ label: String, _ element: XCUIElement) {
        guard element.exists else { note("frame \(label): missing"); return }
        let f = element.frame
        note("frame \(label): \(Int(f.width))x\(Int(f.height)) hittable=\(element.isHittable)")
    }

    private func flushNotes(_ name: String) {
        let att = XCTAttachment(string: notes.joined(separator: "\n"))
        att.name = name
        att.lifetime = .keepAlways
        add(att)
    }

    /// Scrolls the frontmost scroll view up by a screenful and captures it.
    private func scrollAndShoot(_ name: String) {
        app.swipeUp(velocity: .slow)
        shot(name, settle: 0.8)
    }

    // MARK: - 1. First launch to Home

    func testNewcomerFirstRun() {
        launchFresh()
        shot("01_onboarding_welcome", settle: 2.0)
        frameNote("onboarding-continue", app.buttons["onboarding-continue"])

        app.buttons["onboarding-continue"].tap()
        shot("02_onboarding_level")
        // Tap Continue without choosing: what does a person who does not know
        // their level see?
        app.buttons["onboarding-continue"].tap()
        shot("03_onboarding_level_required")
        frameNote("level-required-text", app.staticTexts["onboarding-level-required"])
        frameNote("onboarding-level-new", app.buttons["onboarding-level-new"])

        app.buttons["onboarding-level-new"].tap()
        shot("04_onboarding_level_new_selected", settle: 0.6)
        app.buttons["onboarding-continue"].tap()
        shot("05_onboarding_ready")
        app.buttons["onboarding-continue"].tap()

        // The primer sheet.
        let primerDone = app.buttons["primer-done"]
        _ = primerDone.waitForExistence(timeout: 8)
        shot("06_primer_top", settle: 3.0)
        frameNote("primer-done", primerDone)
        scrollAndShoot("07_primer_scrolled_1")
        scrollAndShoot("08_primer_scrolled_2")
        scrollAndShoot("09_primer_scrolled_3")
        if primerDone.exists { primerDone.tap() }

        // Home.
        shot("10_home_top", settle: 2.0)
        frameNote("mixed-rally", app.buttons["mixed-rally"])
        frameNote("tab Progress", app.tabBars.buttons["Progress"])
        scrollAndShoot("11_home_scroll_1")
        scrollAndShoot("12_home_scroll_2")
        scrollAndShoot("13_home_scroll_3")
        flushNotes("notes_first_run")
    }

    // MARK: - 2. The two "start" doors a newcomer sees

    /// "Get Started" is the big green card, and what a newcomer taps first.
    func testNewcomerGetStarted() {
        launchSkippingIntro()
        let getStarted = app.buttons["Get Started"].firstMatch
        let alt = app.staticTexts["Get Started"].firstMatch
        if getStarted.waitForExistence(timeout: 6) { getStarted.tap() }
        else if alt.exists { alt.tap() }
        else { note("Get Started card not found") }
        shot("20_getstarted_q1", settle: 2.5)
        frameNote("choice-0", app.buttons["choice-0"])
        frameNote("shot-0", app.buttons["shot-0"])
        scrollAndShoot("21_getstarted_q1_scrolled")
        if !tapFirstOption() { note("no option tappable in Get Started") }
        shot("22_getstarted_q1_graded", settle: 1.5)
        scrollAndShoot("23_getstarted_q1_graded_scrolled")
        flushNotes("notes_get_started")
    }

    // MARK: - 3. Play a point, end to end

    func testNewcomerPlayAPoint() {
        launchSkippingIntro()
        guard tapIdentifier("mixed-rally") else { return flushNotes("notes_play") }
        shot("30_ball1_deciding", settle: 4.0)
        for i in 0..<4 { frameNote("shot-\(i)", app.buttons["shot-\(i)"]) }
        frameNote("nav-back", app.buttons["nav-back"])

        _ = tapFirstOption()
        shot("31_ball1_graded", settle: 1.5)
        frameNote("next-ball", app.buttons["next-ball"])
        let tree = XCTAttachment(string: app.debugDescription)
        tree.name = "tree_verdict"
        tree.lifetime = .keepAlways
        add(tree)

        let overhead = app.staticTexts["Show it from above"].firstMatch
        frameNote("show-overhead", overhead)
        if overhead.exists, overhead.isHittable {
            overhead.tap()
            shot("32_ball1_overhead_open", settle: 1.0)
        }
        app.swipeUp(velocity: .slow)
        shot("33_ball1_verdict_scrolled", settle: 0.8)

        // Leave mid-session: does the app explain what is kept?
        app.buttons["nav-back"].tap()
        shot("34_leave_dialog", settle: 1.0)
        let keep = app.buttons["Keep playing"].firstMatch
        if keep.exists { keep.tap() }
        shot("35_after_keep_playing", settle: 1.0)

        // Play to the end of the session.
        for ball in 1..<14 {
            if app.buttons["session-done"].exists { break }
            if app.buttons["next-ball"].exists, app.buttons["next-ball"].isHittable {
                app.buttons["next-ball"].tap()
            }
            settle(2.0)
            if app.buttons["session-done"].exists { break }
            if ball == 2 { shot("36_ball\(ball + 1)_deciding", settle: 0.5) }
            if !tapFirstOption() { break }
            settle(1.2)
            if ball == 2 { shot("37_ball\(ball + 1)_graded", settle: 0.2) }
        }
        if app.buttons["next-ball"].exists, app.buttons["next-ball"].isHittable {
            app.buttons["next-ball"].tap()
        }
        shot("38_summary", settle: 2.0)
        frameNote("session-done", app.buttons["session-done"])
        if app.buttons["session-done"].exists { app.buttons["session-done"].tap() }
        shot("39_home_after_session", settle: 1.5)
        flushNotes("notes_play")
    }

    // MARK: - 4. Settings, progress, paywall door, return visit

    func testNewcomerSecondaryScreens() {
        launchSkippingIntro()
        shot("40_home", settle: 1.5)
        // Progress before any practice.
        if selectTab("Progress") { shot("41_progress_empty", settle: 1.5) }
        if selectTab("Settings") {
            shot("42_settings_top", settle: 1.5)
            scrollAndShoot("43_settings_2")
            scrollAndShoot("44_settings_3")
        }
        // A locked training tile opens the paywall for a free user.
        _ = selectTab("Practice")
        if tapIdentifier("tile-daily") {
            shot("45_paywall_from_daily_tile", settle: 3.0)
            frameNote("Not now", app.buttons["Not now"])
            frameNote("restore", app.buttons["Restore Purchases"])
            app.swipeUp(velocity: .slow)
            shot("46_paywall_scrolled", settle: 1.0)
            if app.buttons["Not now"].exists { app.buttons["Not now"].tap() }
        } else {
            note("tile-daily not reachable on Home without scrolling")
        }
        shot("47_home_after_paywall", settle: 1.5)
        flushNotes("notes_secondary")
    }

    /// Return visit: play one ball, kill the app, relaunch WITHOUT reset.
    func testNewcomerReturnVisit() {
        launchSkippingIntro()
        guard tapIdentifier("mixed-rally") else { return }
        settle(4.0)
        _ = tapFirstOption()
        settle(1.5)
        app.terminate()

        app = XCUIApplication()
        app.launchArguments = ["-subscription.localProOverride", "NO", "-settings.shotClock", "off"]
        app.launch()
        started = Date()
        shot("50_return_launch", settle: 3.0)
        if app.buttons["onboarding-continue"].exists { note("onboarding shown again on return visit") }
        if app.buttons["primer-done"].exists { note("primer shown again on return visit") }
        frameNote("mixed-rally", app.buttons["mixed-rally"])
        scrollAndShoot("51_return_scroll")
        flushNotes("notes_return")
    }

    // MARK: - Setup

    /// Fresh state, but skips onboarding and primer so each test starts at Home.
    private func launchSkippingIntro() {
        app = XCUIApplication()
        app.launchArguments = [
            "-subscription.localProOverride", "NO",
            "-uitest.reset", "YES",
            "-uitest.skipPrimer", "YES",
            "-uitest.seed", "4242",
            "-settings.shotClock", "off",
        ]
        app.launch()
        _ = app.wait(for: .runningForeground, timeout: 30)
        started = Date()
        settle(2.0)
    }
}
