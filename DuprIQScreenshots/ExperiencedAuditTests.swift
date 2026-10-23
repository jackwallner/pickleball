import XCTest

/// Persona audit: an experienced player repeating the core loop and looking for
/// accurate, efficient deeper features. Not part of the App Store set. Every
/// test records what it saw as attachments and notes (`notes` attachment) so a
/// reviewer can read the evidence without rerunning anything.
@MainActor
final class ExperiencedAuditTests: ScreenshotHarness {
    nonisolated(unsafe) var notes: [String] = []

    override func tearDown() {
        let attachment = XCTAttachment(string: notes.joined(separator: "\n"))
        attachment.name = "notes"
        attachment.lifetime = .keepAlways
        add(attachment)
        super.tearDown()
    }

    private func note(_ text: String) { notes.append(text) }

    private func start(
        pro: Bool = false,
        fixture: String? = "demo",
        shotClock: String = "off",
        seed: Int = 4242,
        extra: [String] = []
    ) {
        app = XCUIApplication()
        var args = [
            "-subscription.localProOverride", pro ? "YES" : "NO",
            "-uitest.reset", "YES",
            "-uitest.skipPrimer", "YES",
            "-settings.shotClock", shotClock,
            "-uitest.seed", String(seed),
        ]
        if let fixture { args += ["-uitest.fixture", fixture] }
        app.launchArguments = args + extra
        app.launch()
        _ = app.wait(for: .runningForeground, timeout: 30)
        settle(2.0)
    }

    private func has(_ identifier: String, timeout: TimeInterval = 2) -> Bool {
        app.descendants(matching: .any)[identifier].firstMatch.waitForExistence(timeout: timeout)
    }

    private func lines(_ kind: String) -> String {
        app.debugDescription.split(separator: "\n")
            .filter { $0.contains(kind) }
            .prefix(40)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: " | ")
    }

    private func labels() -> String {
        // One snapshot of the tree. Walking allElementsBoundByIndex resolves
        // every element separately, which stalled the runner on a busy host.
        app.debugDescription.split(separator: "\n")
            .filter { $0.contains("StaticText") }
            .prefix(60)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: " | ")
    }

    // MARK: - 1. First run as an experienced player

    func testE1FirstRunCompetitive() {
        app = XCUIApplication()
        app.launchArguments = [
            "-subscription.localProOverride", "NO",
            "-uitest.reset", "YES",
            "-uitest.seed", "4242",
        ]
        app.launch()
        _ = app.wait(for: .runningForeground, timeout: 30)
        settle(2.0)
        capture("e1_01_welcome")
        app.buttons["onboarding-continue"].tap()
        settle(1.0)
        capture("e1_02_level_page")
        app.buttons["onboarding-level-competitive"].tap()
        settle(0.6)
        capture("e1_03_level_competitive_selected")
        app.buttons["onboarding-continue"].tap()
        settle(1.0)
        capture("e1_04_ready_page")
        app.buttons["onboarding-continue"].tap()
        settle(2.0)
        capture("e1_05_after_onboarding")
        note("after onboarding, primer-done visible: \(has("primer-done"))")
        if app.buttons["primer-done"].exists {
            app.buttons["primer-done"].tap()
            settle(1.5)
        }
        capture("e1_06_lobby_first_open")
        note("lobby texts: \(labels())")
        note("shot clock default after competitive onboarding: check Settings capture")
        selectTab("Settings")
        settle(1.0)
        capture("e1_07_settings_top")
        app.swipeUp()
        settle(0.6)
        capture("e1_08_settings_scrolled")
    }

    // MARK: - 2. Return visit lobby, Endless picker, Progress

    func testE2ReturnVisitLobbyAndPicker() {
        start()
        capture("e2_01_lobby_top")
        note("lobby texts: \(labels())")
        app.swipeUp()
        settle(0.8)
        capture("e2_02_lobby_scrolled_1")
        app.swipeUp()
        settle(0.8)
        capture("e2_03_lobby_scrolled_2")
        app.swipeDown(); app.swipeDown(); app.swipeDown()
        settle(0.8)

        // Endless Practice tile lives in a horizontal row below the fold.
        var tries = 0
        while !app.buttons["tile-endless"].isHittable && tries < 4 {
            app.swipeUp(); settle(0.5); tries += 1
        }
        note("tile-endless hittable after \(tries) swipes: \(app.buttons["tile-endless"].isHittable)")
        capture("e2_04_training_row")
        if app.buttons["tile-endless"].exists {
            app.buttons["tile-endless"].tap()
            settle(1.5)
            capture("e2_05_endless_picker")
            note("picker nav bars: \(lines("NavigationBar"))")
            note("picker nav buttons: \(lines("Button"))")
            note("picker has nav-back id: \(app.buttons["nav-back"].exists)")
            note("picker texts: \(labels())")
            app.swipeUp()
            settle(0.6)
            capture("e2_06_endless_picker_scrolled")
            // How do I get back?
            let back = app.navigationBars.buttons.firstMatch
            if back.exists {
                back.tap()
                settle(1.0)
                capture("e2_07_after_back")
            } else {
                report("endless picker: no back button in navigation bar")
                attachTree("picker_no_back")
            }
        } else {
            report("tile-endless not found")
        }
        selectTab("Progress")
        settle(1.2)
        capture("e2_08_progress")
        note("progress texts: \(labels())")
        app.swipeUp()
        settle(0.6)
        capture("e2_09_progress_scrolled")
        note("locked history row: \(app.buttons["locked-session-history"].exists)")
        if app.buttons["locked-session-history"].exists {
            app.buttons["locked-session-history"].tap()
            settle(2.0)
            capture("e2_10_paywall_from_progress")
        }
    }

    // MARK: - 3. Repeating the core loop, free cap

    func testE3RepeatLoopAndFreeCap() {
        start()
        guard selectTab("Practice") else { return }
        var sessions = 0
        var ballsPlayed = 0
        let began = Date()
        while sessions < 3 {
            guard tapIdentifier("mixed-rally", timeout: 4) else {
                capture("e3_no_rally_button_session_\(sessions)")
                note("could not start session \(sessions + 1); texts: \(labels())")
                break
            }
            sessions += 1
            settle(1.5)
            if sessions == 1 {
                capture("e3_01_first_ball")
                note("first ball HUD texts: \(labels())")
            }
            var ballsThisSession = 0
            while ballsThisSession < 16 {
                if app.buttons["session-done"].exists { break }
                guard tapFirstOption() else { break }
                ballsThisSession += 1
                ballsPlayed += 1
                settle(0.7)
                if sessions == 1 && ballsThisSession == 1 { capture("e3_02_first_verdict") }
                guard tapIdentifier("next-ball", timeout: 4) else { break }
                settle(0.7)
            }
            settle(1.0)
            capture("e3_summary_session_\(sessions)")
            note("session \(sessions): balls answered via UI \(ballsThisSession); summary texts: \(labels())")
            note("summary buttons: \(lines("Button"))")
            if app.buttons["summary-paywall"].exists {
                note("free-limit summary reached in session \(sessions)")
                app.buttons["summary-paywall"].tap()
                settle(2.0)
                capture("e3_paywall_from_summary")
                // Is there a close affordance?
                note("paywall buttons: \(lines("Button"))")
                app.swipeDown(velocity: .fast)
                settle(1.0)
                if app.buttons["session-done"].exists { app.buttons["session-done"].tap() }
                settle(1.0)
                capture("e3_lobby_after_cap")
                // Try to start another ball when capped.
                if app.buttons["mixed-rally"].exists {
                    app.buttons["mixed-rally"].tap()
                    settle(2.0)
                    capture("e3_tap_rally_when_capped")
                }
                break
            }
            if app.buttons["session-done"].exists {
                app.buttons["session-done"].tap()
                settle(1.0)
                capture("e3_lobby_after_session_\(sessions)")
                note("lobby after session \(sessions): \(labels())")
            }
        }
        note("sessions \(sessions), UI-answered balls \(ballsPlayed), seconds \(Int(Date().timeIntervalSince(began)))")
    }

    // MARK: - 4. Decision timer

    func testE4ShotClockTimeoutAndLeaveDialog() {
        start(shotClock: "tournament")
        guard selectTab("Practice") else { return }
        guard tapIdentifier("mixed-rally") else { return }
        settle(1.0)
        capture("e4_01_first_ball_clock_running")
        // Ball 1: let it time out.
        settle(4.0)
        capture("e4_02_timed_out")
        note("timed-out card header present: \(app.staticTexts["Time's up. Point to them."].exists)")
        note("next-ball hittable after timeout: \(app.buttons["next-ball"].isHittable)")
        if app.buttons["next-ball"].exists { app.buttons["next-ball"].tap() }
        settle(0.8)
        capture("e4_03_second_ball")
        // Ball 2: open the leave dialog and let the clock run behind it.
        app.buttons["nav-back"].tap()
        settle(0.5)
        capture("e4_04_leave_dialog_open")
        settle(4.5)
        capture("e4_05_leave_dialog_after_4s")
        note("leave dialog still showing: \(app.buttons["Keep playing"].exists)")
        if app.buttons["Keep playing"].exists {
            app.buttons["Keep playing"].tap()
            settle(0.8)
            capture("e4_06_after_keep_playing")
            note("after Keep playing, timed-out card up: \(app.staticTexts["Time's up. Point to them."].exists)")
            note("after Keep playing, shot-0 hittable: \(app.buttons["shot-0"].isHittable)")
        }
    }

    func testE5SettingsTimerToggle() {
        start()
        guard selectTab("Settings") else { return }
        capture("e5_01_settings")
        let toggle = app.switches["decision-timer-toggle"]
        note("toggle exists: \(toggle.exists)")
        if toggle.exists {
            toggle.tap()
            settle(0.8)
            capture("e5_02_timer_on_default")
            note("pace picker visible: \(app.buttons["decision-timer-pace"].exists || app.otherElements["decision-timer-pace"].exists)")
            note("settings texts: \(labels())")
        }
    }

    // MARK: - 6. Pro experienced view

    func testE6ProProgressAndTiles() {
        start(pro: true)
        capture("e6_01_lobby_pro")
        selectTab("Progress")
        settle(1.2)
        capture("e6_02_progress_pro")
        note("progress pro texts: \(labels())")
        app.swipeUp()
        settle(0.8)
        capture("e6_03_progress_pro_scrolled")
        app.swipeUp()
        settle(0.8)
        capture("e6_04_progress_pro_scrolled_2")
        // Is a missed principle actionable?
        let row = app.staticTexts["Reset off your shoetops, never drive"]
        note("missed principle row exists: \(row.exists)")
        if row.exists, row.isHittable {
            row.tap()
            settle(1.5)
            capture("e6_05_after_tapping_missed_principle")
            note("after tapping missed row, texts: \(labels())")
        }
        selectTab("Practice")
        settle(1.0)
        var tries = 0
        while !app.buttons["tile-fix"].isHittable && tries < 4 {
            app.swipeUp(); settle(0.4); tries += 1
        }
        capture("e6_06_training_tiles_pro")
        note("tile-fix present: \(app.buttons["tile-fix"].exists)")
        if app.buttons["tile-timed"].exists && app.buttons["tile-timed"].isHittable {
            app.buttons["tile-timed"].tap()
            settle(2.0)
            capture("e6_07_timed_challenge")
            note("timed challenge texts: \(labels())")
        }
    }
}
