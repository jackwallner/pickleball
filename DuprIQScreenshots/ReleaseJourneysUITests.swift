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

    /// The product: play a whole run from a fresh install, read the summary,
    /// find the same run counted in Your game, and find it again after a kill.
    func testCoreLoopRunScoresAndSurvivesRelaunch() {
        let proArgs = ["-subscription.localProOverride", "YES", "-settings.shotClock", "off"]
        let app = launch(["-uitest.reset", "YES", "-uitest.seed", "5150"] + proArgs)
        passOnboarding(app)
        XCTAssertTrue(app.buttons["shot-0"].waitForExistence(timeout: 60), "first ball never appeared")
        QA.checkpoint(app, "first-ball")

        var answered = 0
        while !app.buttons["play-again"].exists {
            XCTAssertLessThan(answered, 30, "the run never ended")
            XCTAssertTrue(app.buttons["shot-0"].waitForExistence(timeout: 10), "ball \(answered + 1) never appeared")
            usleep(700_000)  // the court ignores taps for 0.6 s on a new ball
            app.buttons["shot-0"].tap()
            answered += 1
            XCTAssertTrue(app.buttons["next-ball"].waitForExistence(timeout: 10), "no verdict on ball \(answered)")
            if answered == 1 { QA.checkpoint(app, "first-verdict", grace: 4.5) }
            app.buttons["next-ball"].tap()
            _ = app.buttons["shot-0"].waitForExistence(timeout: 10) || app.buttons["play-again"].exists
        }
        XCTAssertTrue(app.buttons["play-again"].waitForExistence(timeout: 10), "summary missing")
        QA.checkpoint(app, "summary")

        let score = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Final score'")).firstMatch
        XCTAssertTrue(score.exists, "summary shows no score")
        let points = score.label.components(separatedBy: CharacterSet.decimalDigits.inverted).compactMap(Int.init)
        XCTAssertEqual(points.count, 2, "unreadable score: \(score.label)")
        let result = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'the best call'")).firstMatch
        XCTAssertTrue(result.exists, "summary shows no result line")
        let counts = result.label.components(separatedBy: CharacterSet.decimalDigits.inverted).compactMap(Int.init)
        XCTAssertEqual(counts.count >= 2 ? counts[1] : -1, answered, "summary counts a different number of balls than were played")

        app.buttons["summary-your-game"].tap()
        assertYourGame(app, answered: answered, correct: counts[0], won: points[0], lost: points[1])
        QA.checkpoint(app, "your-game-after-run")
        app.buttons["your-game-done"].tap()

        app.launchArguments = proArgs  // no reset: the saved game has to come back
        QA.relaunch(app)
        XCTAssertTrue(app.buttons["shot-0"].waitForExistence(timeout: 120), "court missing after relaunch")
        QA.checkpoint(app, "after-relaunch")
        app.buttons["your-game"].tap()
        assertYourGame(app, answered: answered, correct: counts[0], won: points[0], lost: points[1])
        QA.checkpoint(app, "your-game-after-relaunch")
    }

    // MARK: - Helpers

    private func passOnboarding(_ app: XCUIApplication, journey: String = #function) {
        let next = app.buttons["onboarding-continue"]
        XCTAssertTrue(next.waitForExistence(timeout: 120), "onboarding never rendered")
        QA.checkpoint(app, "onboarding-court", journey: journey)
        next.tap()
        XCTAssertTrue(app.buttons["level-rec"].waitForExistence(timeout: 10), "level step missing")
        app.buttons["level-rec"].tap()
        next.tap()
        XCTAssertTrue(app.buttons["half-either"].waitForExistence(timeout: 10), "side step missing")
        app.buttons["half-either"].tap()
        next.tap()
    }

    /// Your game must count the run just played: balls read, streak, and the run row.
    private func assertYourGame(_ app: XCUIApplication, answered: Int, correct: Int, won: Int, lost: Int) {
        XCTAssertTrue(app.buttons["your-game-done"].waitForExistence(timeout: 10), "Your game never opened")
        let balls = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'balls read'")).firstMatch
        XCTAssertTrue(balls.waitForExistence(timeout: 5), "no balls-read stat")
        XCTAssertTrue(balls.label.hasPrefix("\(answered)"), "balls read is '\(balls.label)', expected \(answered)")
        let streak = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'day streak'")).firstMatch
        let days = answered >= MasteryThreshold.ballsForPracticeDay ? 1 : 0  // a day counts at five balls
        XCTAssertTrue(streak.label.hasPrefix("\(days)"), "streak is '\(streak.label)', expected \(days)")
        let run = app.descendants(matching: .any).matching(NSPredicate(
            format: "label CONTAINS %@ AND label CONTAINS %@", "\(won) - \(lost)", "\(correct)/\(answered)")).firstMatch
        XCTAssertTrue(run.waitForExistence(timeout: 5), "the finished run is not listed as \(won) - \(lost), \(correct)/\(answered)")
    }

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
