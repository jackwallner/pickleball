import XCTest

/// Drives the real app to capture the App Store screenshot set.
///
/// State comes from `-uitest.fixture demo` and the court from `-uitest.seed`,
/// so the exported set is a chosen story rather than whatever the simulator was
/// holding. Every capture asserts that the screen it names actually rendered;
/// under `SCREENSHOT_STRICT=1` a missing control fails the run instead of
/// quietly exporting a blank.
///
/// Run: scripts/capture-screenshots.sh <udid> <out-dir> [prefix]
/// Gate: scripts/capture-screenshots.sh --strict <udid> <out-dir>
@MainActor
final class ScreenshotTests: ScreenshotHarness {

    /// 01 Practice lobby: the daily rally, the recommended phase, and the six
    /// phase rooms with their accuracy readouts.
    func test01Lobby() {
        launch()
        guard selectTab("Practice") else { return }
        expect("mixed-rally", on: "lobby")
        expect("room-dinkRally", on: "lobby")
        settle()
        capture("01_lobby")
    }

    /// 02 The court read, before an answer is picked. This is the screen that
    /// has to sell the product: four players' feet and a real question.
    func test02CourtQuestion() {
        launch()
        guard selectTab("Practice") else { return }
        guard tapIdentifier("mixed-rally") else {
            attachTree("court_question")
            return
        }
        settle(2.0)
        expect("shot-0", on: "court question")
        capture("02_court_question")
    }

    /// 03 The graded answer: which shot was right and the principle behind it.
    func test03GradedAnswer() {
        launch()
        guard selectTab("Practice") else { return }
        guard tapIdentifier("mixed-rally") else { return }
        settle(2.0)
        // Any option grades the ball; a wrong pick shows the same answer card.
        guard tapFirstOption() else {
            attachTree("graded_answer")
            return
        }
        settle(1.4)
        // The principle card is the product. A capture without it is not this
        // screenshot, it is the question screen with coloured rows.
        expect("answer-card", on: "graded answer", visible: true)
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
            report("Settings had no See Pro row")
            attachTree("paywall")
            return
        }
        seePro.tap()
        settle(2.0)
        expect("plan-yearly", on: "paywall")
        capture("05_paywall")
    }

    /// 06 The first-run court primer. It is the answer to "what am I looking
    /// at", so it is worth a slot in the set and worth proving it still opens.
    func test06CourtPrimer() {
        // No fixture: this is the genuinely-empty first-run state, with the
        // primer suppression turned back off.
        app = XCUIApplication()
        app.launchArguments = [
            "-subscription.localProOverride", "NO",
            "-uitest.reset", "YES",
            "-uitest.seed", "4242",
        ]
        app.launch()
        _ = app.wait(for: .runningForeground, timeout: 30)
        settle(2.0)
        expect("primer-done", on: "court primer")
        capture("06_court_primer")
    }
}
