import XCTest

/// Not part of the App Store set. This walks the real drill loop slowly enough
/// that a host-side frame grabber can record what the player actually sees, so
/// the first-person court can be audited as an experience rather than as a
/// pile of unit tests that all pass.
@MainActor
final class AuditTests: ScreenshotHarness {

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
            settle(2.4)
            guard tapFirstOption() else { break }
            settle(2.2)
            guard tapIdentifier("next-ball", timeout: 4) else {
                attachTree("ball\(ball)_next")
                break
            }
        }
        settle(2.0)
    }

    /// The two Pro modes that render the court INSIDE a session runner rather
    /// than full bleed. Both were still showing the overhead diagram and a list
    /// of sentences after the pivot.
    func testEmbeddedCourtModes() {
        for tile in ["tile-timed", "tile-warmup"] {
            launchForAudit(seed: 909)
            guard selectTab("Practice") else { return }
            guard tapIdentifier(tile) else {
                attachTree(tile)
                continue
            }
            settle(3.4)
            _ = tapFirstOption()
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
            if tapFirstOption() {
                settle(2.4)
            }
            app.terminate()
        }
    }
}
