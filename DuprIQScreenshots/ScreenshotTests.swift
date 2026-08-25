import XCTest

/// Drives the real app to capture the App Store screenshot set.
///
/// Nothing here calls XCTFail. A UI test that fails spends ten minutes
/// collecting simulator diagnostics before it tells you anything, and a missing
/// element on screen 4 should not throw away screens 1 to 3. Problems are
/// collected and attached instead, and `capture-screenshots.sh` exports
/// whatever was taken regardless of the reported result.
///
/// Run: scripts/capture-screenshots.sh <udid> <out-dir> [prefix]
@MainActor
final class ScreenshotTests: XCTestCase {
    private var app: XCUIApplication!
    private var problems: [String] = []

    // setUp() overrides a nonisolated method, so self is not MainActor-isolated
    // inside it and launching there trips Swift 6's sending check. Each test
    // calls launch() instead.
    override func setUp() {
        continueAfterFailure = true
    }

    override func tearDown() {
        guard !problems.isEmpty else { return }
        let note = XCTAttachment(string: problems.joined(separator: "\n"))
        note.name = "problems"
        note.lifetime = .keepAlways
        add(note)
    }

    /// 01 Practice lobby: the daily rally, the weakest-phase shortcut, and the
    /// six phase rooms with their accuracy readouts.
    func test01Lobby() {
        launch()
        guard selectTab("Practice") else { return }
        settle()
        capture("01_lobby")
    }

    /// 02 The court read, before an answer is picked. This is the screen that
    /// has to sell the product: four players' feet and a real question.
    func test02CourtQuestion() {
        launch()
        guard selectTab("Practice") else { return }
        guard tapIdentifier("mixed-rally") else {
            problems.append("could not start the mixed rally")
            attachTree("court_question")
            return
        }
        settle(2.0)
        capture("02_court_question")
    }

    /// 03 The graded answer: which shot was right and the principle behind it.
    func test03GradedAnswer() {
        launch()
        guard selectTab("Practice") else { return }
        guard tapIdentifier("mixed-rally") else {
            problems.append("could not start the mixed rally")
            return
        }
        settle(2.0)
        // Any option grades the ball; a wrong pick shows the same answer card.
        guard tapFirstOption() else {
            problems.append("could not pick a shot option")
            attachTree("graded_answer")
            return
        }
        settle(1.4)
        capture("03_graded_answer")
    }

    /// 04 Progress by phase: the readout that tells you which part of the point
    /// is actually costing you games.
    func test04Progress() {
        launch()
        guard selectTab("Progress") else { return }
        settle()
        capture("04_progress")
    }

    /// 05 The paywall. `PaywallRenderTests` covers it in isolation with the
    /// StoreKit catalog attached; this is the in-context version.
    func test05Paywall() {
        launch()
        guard selectTab("Settings") else { return }
        settle()
        let seePro = app.buttons["See Pro"].firstMatch
        guard seePro.waitForExistence(timeout: 4) else {
            problems.append("Settings had no See Pro row")
            attachTree("paywall")
            return
        }
        seePro.tap()
        settle(2.0)
        capture("05_paywall")
    }

    // MARK: - Helpers

    private func launch() {
        app = XCUIApplication()
        // Start from a clean free account: the local Pro override is what the
        // Settings toggle flips, and a leftover YES hides the paywall entirely.
        app.launchArguments = ["-subscription.localProOverride", "NO"]
        app.launch()
        _ = app.wait(for: .runningForeground, timeout: 30)
        settle()
    }

    private func selectTab(_ name: String) -> Bool {
        let tab = app.tabBars.buttons[name].firstMatch
        guard tab.waitForExistence(timeout: 8) else {
            problems.append("no \(name) tab")
            return false
        }
        tab.tap()
        return true
    }

    private func tapIdentifier(_ identifier: String) -> Bool {
        let element = app.descendants(matching: .any)[identifier].firstMatch
        guard element.waitForExistence(timeout: 6) else { return false }
        element.tap()
        return true
    }

    /// The four shot options are plain buttons carrying the shot label, so the
    /// stable handle is position: skip the nav bar and take the first button
    /// inside the scroll view.
    private func tapFirstOption() -> Bool {
        let buttons = app.scrollViews.buttons
        guard buttons.firstMatch.waitForExistence(timeout: 6) else { return false }
        let candidate = buttons.element(boundBy: 0)
        guard candidate.exists, candidate.isHittable else { return false }
        candidate.tap()
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
