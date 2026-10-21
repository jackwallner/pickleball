import XCTest

/// Drives the real app to capture the App Store screenshot set.
///
/// State comes from `-uitest.fixture demo` and the court from `-uitest.seed`,
/// so the exported set is a chosen story rather than whatever the simulator was
/// holding. Every capture asserts that the screen it names actually rendered;
/// under `SCREENSHOT_STRICT=1` a missing control fails the run.
///
/// Run: scripts/capture-screenshots.sh <udid> <out-dir> [prefix]
/// Gate: scripts/capture-screenshots.sh --strict <udid> <out-dir>
@MainActor
final class ScreenshotTests: ScreenshotHarness {

    /// 01 The court, before an answer: four players' feet, the ball's height
    /// against the net, and four places to put it. The app opens here.
    func test01CourtQuestion() {
        launch()
        settle(2.0)
        expect("shot-0", on: "court question")
        capture("01_court_question")
    }

    /// 02 The graded ball, with your shot and the right one replayed on the
    /// court and the principle behind the answer.
    func test02Replay() {
        launch()
        settle(2.0)
        guard tapFirstOption() else {
            attachTree("replay")
            return
        }
        // Long enough for both replayed paths to land and leave their trails.
        settle(3.4)
        expect("answer-card", on: "graded answer", visible: true)
        capture("02_replay")
    }

    /// 03 Your game: mastery per principle and the traps costing points.
    func test03YourGame() {
        launch()
        guard tapIdentifier("your-game") else { return attachTree("your_game") }
        // The tap alone proves nothing: on iPad the page sheet was still
        // presenting at 1.4 s and the shot showed the bare court.
        expect("open-settings", on: "your_game", visible: true)
        settle(1.0)
        capture("03_your_game")
    }

    /// 04 The paywall, reached from a locked row in Your game.
    func test04Paywall() {
        launch()
        guard tapIdentifier("your-game") else { return attachTree("paywall") }
        settle(1.0)
        guard tapIdentifier("your-game-pro") else { return attachTree("paywall") }
        settle(2.0)
        expect("plan-yearly", on: "paywall")
        capture("04_paywall")
    }

    /// 05 First launch: what the court is, before the two setup questions.
    func test05Onboarding() {
        launch(fixture: nil)
        settle(2.0)
        expect("onboarding-continue", on: "onboarding")
        capture("05_onboarding")
    }
}
