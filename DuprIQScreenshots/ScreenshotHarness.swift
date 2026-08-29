import XCTest

/// Shared launch and navigation for the capture targets.
///
/// Two things this fixes, both of which the last audit caught on real output.
///
/// First, determinism. The captures used to launch with whatever the simulator
/// was holding: a one-day streak from a previous run, twelve of fifteen free
/// balls left, and phase percentages nobody chose. `-uitest.fixture demo` and
/// `-uitest.seed` replace that with a stated story and a fixed court, so a
/// re-run produces the same App Store asset.
///
/// Second, honesty about failure. Collecting problems instead of failing is
/// right for a diagnostic run and wrong for a release gate: an iPad run once
/// reported four passing tests whose only output said "no Practice tab". Set
/// `SCREENSHOT_STRICT=1` and a missing control fails the test.
@MainActor
class ScreenshotHarness: XCTestCase {
    var app: XCUIApplication!
    var problems: [String] = []

    /// Release gate: fail loudly rather than exporting a partial set.
    var isStrict: Bool {
        ProcessInfo.processInfo.environment["SCREENSHOT_STRICT"] == "1"
    }

    override func setUp() {
        // Deliberately not `false`: one missing element on screen 4 should not
        // throw away screens 1 to 3 during a diagnostic run.
        continueAfterFailure = true
    }

    override func tearDown() {
        // Always attached, so a green run can be checked for whether the gate
        // was actually armed. A strict run that silently was not strict is a
        // worse outcome than a red one.
        let info = XCTAttachment(string: """
        strict: \(isStrict)
        problems: \(problems.isEmpty ? "none" : "\n" + problems.joined(separator: "\n"))
        """)
        info.name = problems.isEmpty ? "run_info" : "problems"
        info.lifetime = .keepAlways
        add(info)
    }

    // MARK: - Launch

    /// `fixture` seeds a curated history; pass `nil` for a genuinely empty
    /// first-run state. `seed` pins the generated court.
    func launch(fixture: String? = "demo", seed: Int? = 4242) {
        app = XCUIApplication()
        var arguments = [
            // Start from a clean free account: the local Pro override is what
            // the Settings toggle flips, and a leftover YES hides the paywall.
            "-subscription.localProOverride", "NO",
            "-uitest.reset", "YES",
            "-uitest.skipPrimer", "YES",
            // The App Store set is captured a couple of seconds after the court
            // appears, and on the default match clock that is a shot clock ring
            // two thirds drained and turning red. A store asset should not open
            // on "you are about to lose this ball".
            "-settings.shotClock", "relaxed",
        ]
        if let fixture { arguments += ["-uitest.fixture", fixture] }
        if let seed { arguments += ["-uitest.seed", String(seed)] }
        app.launchArguments = arguments
        app.launch()
        _ = app.wait(for: .runningForeground, timeout: 30)
        settle()
    }

    // MARK: - Navigation

    /// iPhone draws the three sections as a tab bar; iPad can render the same
    /// `TabView` as a segmented control in the navigation bar, where
    /// `app.tabBars` finds nothing. The old helper only knew the first shape,
    /// which is why every iPad run reported "no Practice tab".
    @discardableResult
    func selectTab(_ name: String) -> Bool {
        let candidates: [XCUIElement] = [
            app.tabBars.buttons[name].firstMatch,
            app.segmentedControls.buttons[name].firstMatch,
            app.navigationBars.buttons[name].firstMatch,
            app.buttons[name].firstMatch,
        ]
        for candidate in candidates where candidate.waitForExistence(timeout: 3) {
            guard candidate.isHittable else { continue }
            candidate.tap()
            settle(1.0)
            return true
        }
        return report("no \(name) tab")
    }

    @discardableResult
    func tapIdentifier(_ identifier: String, timeout: TimeInterval = 6) -> Bool {
        let element = app.descendants(matching: .any)[identifier].firstMatch
        guard element.waitForExistence(timeout: timeout) else {
            return report("no element with identifier \(identifier)")
        }
        element.tap()
        return true
    }

    /// The four shot options are plain buttons carrying the shot label, so the
    /// stable handle is position: take the first button inside the scroll view.
    @discardableResult
    /// Taps one of the four aim targets on the court.
    ///
    /// Addressed by identifier rather than by "the first button inside a scroll
    /// view", which is how this used to find them and which silently stopped
    /// working the day the drill became a full-bleed court with no scroll view
    /// in it. The run still passed and reported "no shot options on screen",
    /// which is exactly the kind of green-but-wrong result --strict exists for.
    ///
    /// Any option grades the ball; a wrong pick shows the same answer card.
    func tapFirstOption() -> Bool {
        for index in 0..<4 {
            let candidate = app.buttons["shot-\(index)"]
            guard candidate.waitForExistence(timeout: index == 0 ? 6 : 1) else { continue }
            guard candidate.isHittable else { continue }
            candidate.tap()
            return true
        }
        return report("no aim target on the court was hittable")
    }

    // MARK: - Reporting

    /// Records a problem, and fails the test when this is a release gate.
    @discardableResult
    func report(_ message: String) -> Bool {
        problems.append(message)
        if isStrict { XCTFail(message) }
        return false
    }

    /// Asserts that a screen actually rendered what the screenshot claims.
    /// A green run that captured an empty view is worse than a red one.
    ///
    /// `visible` additionally requires the element to be hittable: `exists` is
    /// true for something scrolled off the screen, which is exactly the failure
    /// an "is the explanation actually on this screenshot" check has to catch.
    func expect(
        _ identifier: String, on screen: String,
        visible: Bool = false, timeout: TimeInterval = 6
    ) {
        let element = app.descendants(matching: .any)[identifier].firstMatch
        guard element.waitForExistence(timeout: timeout) else {
            report("\(screen): expected \(identifier) to be on screen")
            attachTree(screen)
            return
        }
        if visible && !element.isHittable {
            report("\(screen): \(identifier) exists but is not visible on screen")
            attachTree(screen)
        }
    }

    func settle(_ seconds: TimeInterval = 1.6) {
        Thread.sleep(forTimeInterval: seconds)
    }

    func capture(_ name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    func attachTree(_ name: String) {
        let tree = XCTAttachment(string: app.debugDescription)
        tree.name = "tree_\(name)"
        tree.lifetime = .keepAlways
        add(tree)
    }
}
