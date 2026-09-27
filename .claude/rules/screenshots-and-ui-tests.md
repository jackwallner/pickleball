---
paths:
  - "DuprIQScreenshots/*"
  - "DuprIQUITests/*.swift"
  - "scripts/capture-*.sh"
  - "Shared/Services/DebugFixtures.swift"
  - "Shared/Services/SubscriptionService.swift"
---

# DUPR IQ: screenshots and UI tests

Moved verbatim from AGENTS.md. Loads when a matching file is read; update it here.

- **Screenshots run headlessly off the `Screenshots` scheme.**
  `DuprIQScreenshots` is a ui-testing target kept out of the `DuprIQ` scheme's
  test action on purpose, so the unit-test loop stays instant. Drive it with
  `scripts/capture-screenshots.sh <udid> <out>` (six shots) and
  `scripts/capture-paywall.sh <udid> <out>` (the paywall alone, with prices).

- **An identifier on a container beats the ones inside it.** `answer-card` was
  applied to the whole `VerdictCard`, and SwiftUI handed it down to every view
  in the card: the primary button reported `answer-card` and `next-ball` did not
  exist anywhere in the tree, so every capture run walked exactly one ball and
  reported success. Identifiers go on the control, before the layout modifiers.

- **`DuprIQScreenshots/AuditTests` is the audit tool, not part of the set.** It
  walks the real loop slowly enough for a host-side `simctl io screenshot` loop
  to record it. That is how the framing failures in `court-3d.md` were found; none of them
  showed up in a passing suite.

- **Screenshot state is a fixture, not the simulator's leftovers.**
  `DebugFixtures` reads DEBUG-only launch arguments through the `UserDefaults`
  argument domain: `-uitest.reset YES` wipes progress, the cap and review state,
  `-uitest.fixture demo` installs a curated four-week history, and
  `-uitest.seed <n>` pins the drill instead of using the wall clock. Without
  them the App Store set is whatever a previous test account happened to leave
  behind.

- **`--strict` is the screenshot release gate.** Plain runs collect problems as
  an attachment and still report success, which is right for iterating and
  wrong before an upload: an iPad run once reported four passing tests whose
  only output said "no Practice tab". `scripts/capture-screenshots.sh --strict`
  turns a missing control into a failure and a non-zero exit. The flag reaches
  the test process through `Screenshots.xctestplan`'s
  `environmentVariableEntries`, because a test plan owns the test environment
  and a bare `TEST_RUNNER_` build setting never arrives. Every run attaches
  `run_info` naming whether strict was actually armed.

- **The paywall's prices on a simulator come from the bundled `.storekit`.**
  `SubscriptionService` never configures RevenueCat on a sim, so
  `paywallPrice(for:)` falls back to a DEBUG-only catalog reader. That is the
  only way to screenshot a paywall showing real money; without it the sheet
  renders its empty state. Keep the fallback amounts in
  `pricesFromStoreKitCatalog()` in step with `DuprIQ.storekit`.

- Both `setUp()` and any other override of a nonisolated XCTestCase method run
  outside the MainActor even on a `@MainActor` test class, so launching the app
  there trips Swift 6's sending check. Launch from the test body.
