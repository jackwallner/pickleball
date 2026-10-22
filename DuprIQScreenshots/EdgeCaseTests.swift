import XCTest

/// Adversarial walks found by the edge-case review: Dynamic Type, iPad, rapid
/// taps, the free limit, the shot clock. Not part of the App Store set.
/// Screenshots, trees and a log go to build/edgecase/shots/<EDGE_TAG>/
/// (EDGE_TAG comes from TEST_RUNNER_EDGE_TAG).
@MainActor
final class EdgeCaseTests: ScreenshotHarness {

    private var tag: String { ProcessInfo.processInfo.environment["EDGE_TAG"] ?? "default" }
    private var dir: URL {
        // The simulator shares the host's file system, so the repo's build
        // folder is reachable from the test process.
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let url = repo.appendingPathComponent("build/edgecase/shots/\(tag)")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func snap(_ name: String) {
        let png = XCUIScreen.main.screenshot().pngRepresentation
        try? png.write(to: dir.appendingPathComponent("\(name).png"))
    }

    private func dump(_ name: String) {
        try? app.debugDescription.write(
            to: dir.appendingPathComponent("\(name).tree.txt"), atomically: true, encoding: .utf8)
    }

    private func log(_ line: String) {
        let url = dir.appendingPathComponent("log.txt")
        let data = (line + "\n").data(using: .utf8)!
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile(); handle.write(data); try? handle.close()
        } else {
            try? data.write(to: url)
        }
    }

    /// Frames of the controls that matter, against the screen.
    private func metrics(_ name: String) {
        var parts = ["[\(name)] screen=\(app.frame.integral)"]
        for id in ["shot-0", "shot-1", "shot-2", "shot-3", "answer-card", "expand-why", "replay",
                   "next-ball", "your-game", "focus-ball", "play-again", "summary-paywall",
                   "summary-your-game", "onboarding-continue"] {
            let e = app.descendants(matching: .any)[id].firstMatch
            if e.exists { parts.append("\(id)=\(e.frame.integral) hit=\(e.isHittable)") }
        }
        log(parts.joined(separator: " "))
    }

    private func launchEdge(
        seed: Int = 4242, clock: String = "off", pro: Bool = true,
        fixture: Bool = true, extra: [String] = [], reset: Bool = true
    ) {
        app = XCUIApplication()
        var args = [
            "-subscription.localProOverride", pro ? "YES" : "NO",
            "-uitest.seed", String(seed),
            "-settings.shotClock", clock,
        ]
        if reset { args += ["-uitest.reset", "YES"] }
        if fixture { args += ["-uitest.fixture", "demo"] }
        app.launchArguments = args + extra
        app.launch()
        _ = app.wait(for: .runningForeground, timeout: 30)
        if fixture { _ = app.buttons["shot-0"].waitForExistence(timeout: 300) }
        settle(2.0)
    }

    private func back() {
        let b = app.navigationBars.buttons.element(boundBy: 0)
        if b.exists { b.tap() }
    }

    private func tap(_ id: String, timeout: TimeInterval = 4) -> Bool {
        let e = app.descendants(matching: .any)[id].firstMatch
        guard e.waitForExistence(timeout: timeout) else { return false }
        e.tap()
        return true
    }

    // MARK: 1. onboarding at whatever size the sim is set to

    func testOnboardingWalk() {
        launchEdge(fixture: false)
        _ = app.buttons["onboarding-continue"].waitForExistence(timeout: 60)
        settle(1.5)
        snap("ob1-court"); metrics("ob1"); dump("ob1")
        _ = tap("onboarding-continue")
        settle(1.0)
        snap("ob2-level"); metrics("ob2"); dump("ob2")
        _ = tap("level-new")
        settle(0.5)
        snap("ob2b-level-picked")
        _ = tap("onboarding-continue")
        settle(1.0)
        snap("ob3-half"); metrics("ob3"); dump("ob3")
        _ = tap("half-left")
        _ = tap("onboarding-continue")
        _ = app.buttons["shot-0"].waitForExistence(timeout: 8)
        settle(1.5)
        snap("ob4-first-court"); metrics("ob4"); dump("ob4")
    }

    // MARK: 2. court, option band, verdict compact + expanded, over several balls

    func testCourtAndVerdictSweep() {
        launchEdge(seed: 4242)
        snap("c0-deciding"); metrics("c0-deciding"); dump("c0-deciding")
        var sawFocus = false
        for ball in 0..<9 {
            guard app.buttons["shot-\(ball % 4)"].waitForExistence(timeout: 6) else { break }
            if app.descendants(matching: .any)["focus-ball"].exists && !sawFocus {
                sawFocus = true
                snap("focus-hud"); metrics("focus-hud")
            }
            if ball < 3 { snap("b\(ball)-deciding") }
            app.buttons["shot-\(ball % 4)"].tap()
            settle(4.0)
            snap("b\(ball)-card"); metrics("b\(ball)-card")
            if ball < 3 { dump("b\(ball)-card") }
            _ = tap("expand-why")
            settle(1.2)
            snap("b\(ball)-expanded"); metrics("b\(ball)-expanded")
            if ball < 3 { dump("b\(ball)-expanded") }
            // scroll inside the expanded card if it still can
            _ = tap("expand-why")
            settle(0.8)
            if !tap("next-ball") { snap("b\(ball)-NO-NEXT"); break }
            settle(1.0)
        }
    }

    // MARK: 3. Your game, Settings, coaching

    func testYourGameAndSettings() {
        launchEdge(seed: 4242)
        _ = tap("your-game")
        settle(1.5)
        snap("yg1-top"); metrics("yg1"); dump("yg1")
        _ = tap("open-settings")
        settle(1.2)
        snap("st1-top"); dump("st1")
        app.swipeUp(); settle(0.6); snap("st2-scroll")
        app.swipeUp(); settle(0.6); snap("st3-scroll")
        let how = app.buttons["How answers are decided"].firstMatch
        if how.waitForExistence(timeout: 2) {
            if !how.isHittable { app.swipeUp() }
            how.tap(); settle(1.0); snap("st4-coaching"); dump("st4")
            app.swipeUp(); settle(0.6); snap("st5-coaching-scroll")
            back(); settle(0.6)
        }
        back(); settle(0.8)
        snap("yg1b-back"); dump("yg1b")
        app.swipeUp(); settle(0.6); snap("yg2-scroll1")
        app.swipeUp(); settle(0.6); snap("yg3-scroll2")
        app.swipeUp(); settle(0.6); snap("yg4-scroll3")
    }

    // MARK: 4. free-limit path

    func testFreeLimitPath() {
        launchEdge(seed: 8080, pro: false)
        var graded = 0
        var run = 1
        for _ in 0..<40 {
            if app.buttons["play-again"].exists {
                snap("fl-summary-run\(run)"); metrics("fl-summary-run\(run)"); dump("fl-summary-run\(run)")
                log("summary after run \(run), graded=\(graded)")
                run += 1
                app.buttons["play-again"].tap(); settle(1.5)
                snap("fl-after-playagain-run\(run)"); metrics("fl-after-playagain-run\(run)")
                continue
            }
            if app.buttons["summary-paywall"].exists { break }
            guard app.buttons["shot-0"].waitForExistence(timeout: 5) else { break }
            let hud = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'free'")).firstMatch
            log("ball \(graded + 1) hud=\(hud.exists ? hud.label : "-")")
            if graded == 13 || graded == 14 { snap("fl-ball\(graded + 1)-deciding") }
            app.buttons["shot-0"].tap()
            graded += 1
            settle(0.9)
            if graded >= 14 { snap("fl-ball\(graded)-card"); metrics("fl-ball\(graded)-card") }
            guard tap("next-ball") else { break }
            settle(0.6)
        }
        settle(1.0)
        snap("fl-final-summary"); metrics("fl-final-summary"); dump("fl-final-summary")
        log("final graded=\(graded)")
        if tap("summary-paywall", timeout: 2) { settle(2.0); snap("fl-paywall"); dump("fl-paywall") }
    }

    /// Free limit reached, relaunch (state persists? reset flag would wipe) so
    /// just check the summary offers Your game and it works.
    func testFreeLimitSummaryYourGame() {
        launchEdge(seed: 8081, pro: false)
        for _ in 0..<40 {
            if app.buttons["play-again"].exists { app.buttons["play-again"].tap(); settle(1) ; continue }
            if app.buttons["summary-paywall"].exists { break }
            guard app.buttons["shot-0"].waitForExistence(timeout: 5) else { break }
            app.buttons["shot-0"].tap(); settle(0.6)
            guard tap("next-ball") else { break }
            settle(0.4)
        }
        _ = tap("summary-your-game", timeout: 3)
        settle(1.5)
        snap("fls-yourgame"); dump("fls-yourgame")
        _ = tap("your-game-done")
        settle(1.0)
        snap("fls-back")
    }

    /// Run after testFreeLimitSummaryYourGame (state persists): relaunch with the limit already spent.
    func testRelaunchAtLimit() {
        launchEdge(seed: 9090, pro: false, fixture: false, reset: false)
        settle(2.0)
        snap("rl-relaunch"); metrics("rl"); dump("rl")
        log("rl: summary-paywall=\(app.buttons["summary-paywall"].exists) play-again=\(app.buttons["play-again"].exists) shot-0=\(app.buttons["shot-0"].exists) onboarding=\(app.buttons["onboarding-continue"].exists)")
    }

    // MARK: 5. rapid input, with free counter as an oracle

    private func freeLeft() -> String {
        let hud = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'free'")).firstMatch
        return hud.exists ? hud.label : "?"
    }

    func testDoubleTapOption() {
        launchEdge(seed: 5150, pro: false)
        log("start: \(freeLeft())")
        app.buttons["shot-1"].doubleTap()
        settle(2.5)
        snap("dt-after-doubletap"); metrics("dt1")
        log("after doubleTap(shot-1): \(freeLeft()) next=\(app.buttons["next-ball"].exists)")
        // The "free left" HUD is hidden behind nothing, still readable.
        _ = tap("next-ball"); settle(1.0)
        log("next ball: \(freeLeft())")
        // two quick taps on two different options
        let a = app.buttons["shot-0"], b = app.buttons["shot-3"]
        a.tap(); b.tap()
        settle(2.5)
        snap("dt-two-options"); metrics("dt2")
        log("after tap shot-0 then shot-3: \(freeLeft())")
        _ = tap("next-ball"); settle(1.0)
        log("next ball: \(freeLeft())")
    }

    func testDoubleTapNext() {
        launchEdge(seed: 5151, pro: false)
        app.buttons["shot-1"].tap()
        settle(3.0)
        log("before double next: \(freeLeft())")
        app.buttons["next-ball"].doubleTap()
        settle(2.5)
        snap("dn-after-double-next"); metrics("dn")
        log("after double next: \(freeLeft()) shot-0=\(app.buttons["shot-0"].exists) next=\(app.buttons["next-ball"].exists)")
    }

    func testTapNextThenImmediateOptionTap() {
        launchEdge(seed: 5152, pro: false)
        app.buttons["shot-2"].tap(); settle(3.0)
        snap("tn-before"); dump("tn-before"); metrics("tn-before")
        guard app.buttons["next-ball"].exists else { return log("tn: no next-ball after shot-2 tap, free=\(freeLeft())") }
        // simulate a heavy-thumb double tap: Next, then the same coordinate again 120 ms later
        let f = app.buttons["next-ball"].frame
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let c = origin.withOffset(CGVector(dx: f.midX, dy: f.midY))
        let t0 = Date()
        c.tap()
        let t1 = Date()
        Thread.sleep(forTimeInterval: 0.12); c.tap()
        let t2 = Date()
        log(String(format: "tap timing: first tap returned %.2fs, second tap returned %.2fs", t1.timeIntervalSince(t0), t2.timeIntervalSince(t0)))
        settle(2.0)
        snap("tn-after"); metrics("tn")
        log("tap/tap at next coordinate: \(freeLeft()) next=\(app.buttons["next-ball"].exists)")
    }

    func testExpandReplayMash() {
        launchEdge(seed: 4141)
        app.buttons["shot-1"].tap()
        settle(0.9)
        for i in 0..<8 {
            _ = tap(i % 2 == 0 ? "expand-why" : "replay", timeout: 2)
            Thread.sleep(forTimeInterval: 0.12)
        }
        settle(0.3); snap("mash-1")
        settle(5.0); snap("mash-2"); metrics("mash"); dump("mash")
        // drag the card while a replay runs
        _ = tap("replay", timeout: 2)
        settle(0.5)
        let grab = app.buttons["expand-why"].firstMatch
            .coordinate(withNormalizedOffset: CGVector(dx: -4, dy: 0.5))
        grab.press(forDuration: 0.05, thenDragTo: grab.withOffset(CGVector(dx: 0, dy: -200)))
        settle(0.3); snap("drag-1")
        settle(3.0); snap("drag-2"); metrics("drag")
        grab.press(forDuration: 0.05, thenDragTo: grab.withOffset(CGVector(dx: 0, dy: 200)))
        settle(1.0); snap("drag-3"); metrics("drag3")
        // next while expanded
        _ = tap("expand-why", timeout: 2); settle(0.6)
        _ = tap("next-ball", timeout: 2)
        settle(0.5); snap("next-from-expanded"); metrics("nfe")
        log("after next from expanded: shot-0=\(app.buttons["shot-0"].exists) expand=\(app.buttons["expand-why"].exists)")
    }

    func testNextMidReplayAndPickDuringTransition() {
        launchEdge(seed: 6061)
        for i in 0..<4 {
            app.buttons["shot-\(i)"].tap()
            settle(0.35)
            _ = tap("next-ball", timeout: 2)
            settle(0.15)
            snap("nm-\(i)-immediately-after-next")
        }
        settle(1.0); snap("nm-end"); metrics("nm-end")
    }

    // MARK: 6. shot clock

    func testShotClockYourGameThenSettingsOff() {
        launchEdge(seed: 7070, clock: "relaxed", pro: false)
        snap("sc0")
        settle(2.0)
        _ = tap("your-game")
        settle(1.2)
        snap("sc1-yourgame-open")
        // clock should be paused: wait past the full 9 s
        settle(11.0)
        _ = tap("open-settings"); settle(1.0)
        snap("sc2-settings")
        // set timer to Off while mid-ball
        let picker = app.buttons["settings-timer"].firstMatch
        if picker.waitForExistence(timeout: 3) {
            picker.tap(); settle(0.8); snap("sc3-picker")
            let off = app.buttons["Off"].firstMatch
            if off.exists { off.tap() }
            settle(0.8)
        }
        snap("sc4-settings-off"); dump("sc4")
        app.navigationBars.buttons.element(boundBy: 0).tap(); settle(0.5)
        _ = tap("your-game-done"); settle(1.0)
        snap("sc5-back-on-court-clock-off"); metrics("sc5")
        log("sc5: free=\(freeLeft()) shot-0=\(app.buttons["shot-0"].exists) next=\(app.buttons["next-ball"].exists) clockRing=\(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'seconds left'")).count)")
        settle(12.0)
        snap("sc6-12s-later"); metrics("sc6")
        log("sc6: next=\(app.buttons["next-ball"].exists) answerCard=\(app.descendants(matching: .any)["answer-card"].exists) free=\(freeLeft())")
    }

    func testShotClockExpiryAndBackground() {
        launchEdge(seed: 7071, clock: "tournament", pro: false)
        // background for 6 s mid-clock
        settle(0.8)
        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 6)
        app.activate()
        settle(0.4)
        snap("sb1-after-background")
        log("after 6s background: next=\(app.buttons["next-ball"].exists) shot-0=\(app.buttons["shot-0"].exists)")
        settle(4.0)
        snap("sb2-expired"); metrics("sb2"); dump("sb2")
        log("expired: answerCard=\(app.descendants(matching: .any)["answer-card"].exists) free=\(freeLeft())")
        // expanded, then next -> next ball's ring restarts
        _ = tap("expand-why"); settle(1.0); snap("sb3-expanded-timeout"); metrics("sb3")
        _ = tap("expand-why"); settle(0.6)
        _ = tap("next-ball"); settle(0.3)
        snap("sb4-new-ball-clock"); metrics("sb4")
        // open Your game, wait past expiry, close
        settle(1.0)
        _ = tap("your-game"); settle(5.0)
        _ = tap("your-game-done"); settle(0.3)
        snap("sb5-after-yourgame"); metrics("sb5")
        log("after your game 5s: next=\(app.buttons["next-ball"].exists)")
    }

    func testShotClockOnLastFreeBall() {
        // 3 s clock on the free tier: let balls expire until the limit, no taps on options
        launchEdge(seed: 7072, clock: "tournament", pro: false)
        var n = 0
        for _ in 0..<40 {
            if app.buttons["play-again"].exists { log("expire-run summary after \(n) expiries"); app.buttons["play-again"].tap(); settle(1); continue }
            if app.buttons["summary-paywall"].exists { break }
            if app.buttons["next-ball"].waitForExistence(timeout: 6) {
                n += 1
                app.buttons["next-ball"].tap(); settle(0.3)
            }
        }
        settle(1.0)
        snap("sl-final"); metrics("sl-final"); dump("sl-final")
        log("expiries=\(n)")
    }

    // MARK: 8. background with an expanded card

    func testBackgroundWhileExpanded() {
        launchEdge(seed: 4143)
        app.buttons["shot-1"].tap(); settle(3.0)
        _ = tap("expand-why"); settle(1.0)
        snap("bg-expanded-before")
        XCUIDevice.shared.press(.home); settle(2.0)
        app.activate(); settle(0.8)
        snap("bg-expanded-after-0.8s")
        settle(4.0)
        snap("bg-expanded-after-5s"); metrics("bg")
    }

    // MARK: 7. accessibility tree at rest (court deciding, card, summary)

    func testAccessibilityTrees() {
        launchEdge(seed: 4242)
        dump("ax-court")
        let q = app.descendants(matching: .any)
        var rows: [String] = []
        for t in [XCUIElement.ElementType.button, .staticText, .image, .other] {
            for e in app.descendants(matching: t).allElementsBoundByIndex.prefix(80) {
                rows.append("\(t.rawValue) id='\(e.identifier)' label='\(e.label)' value='\(e.value ?? "")' hit=\(e.isHittable) frame=\(e.frame.integral)")
            }
        }
        _ = q
        try? rows.joined(separator: "\n").write(
            to: dir.appendingPathComponent("ax-court.rows.txt"), atomically: true, encoding: .utf8)
        app.buttons["shot-0"].tap(); settle(4.0)
        dump("ax-card")
        _ = tap("expand-why"); settle(1.0)
        dump("ax-card-expanded")
        _ = tap("expand-why"); settle(0.5)
        // finish a run (pro, 12 balls)
        for _ in 0..<30 {
            if app.buttons["play-again"].exists { break }
            guard tap("next-ball", timeout: 3) else {
                if app.buttons["shot-0"].exists { app.buttons["shot-0"].tap(); settle(1.0) } else { break }
                continue
            }
            settle(0.4)
            if app.buttons["shot-0"].waitForExistence(timeout: 3) { app.buttons["shot-0"].tap(); settle(0.8) }
        }
        settle(1.0)
        snap("ax-summary"); dump("ax-summary"); metrics("ax-summary")
    }
}
