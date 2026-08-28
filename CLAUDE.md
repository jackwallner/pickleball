# DUPR IQ — Project Guide

Pickleball shot-selection drills: a generated court position, four shot
options, and a named principle for the answer. XcodeGen project/scheme:
`DuprIQ`, sim lease owner `pickleball`. Bundle ID `com.jackwallner.pickleball`.

## Why this app exists

Jack asked for a pickleball trainer that grades the optimal hit and
placement from the situation and the four players' feet. The generator is
the product: it never runs out, every position is physically legal, and
every answer names the principle it came from. The money search term is
`pickleball drills`. Store name is `DUPR IQ`; subtitle should carry
`Pickleball Drills`.

## Tech Stack
- Swift 6 / SwiftUI (strict concurrency)
- XcodeGen (`project.yml`). Targets: iOS 17+, `DuprIQTests`
- RevenueCat entitlement `pro`, membership brand `DUPR IQ Pro`

## Targets / bundle IDs
- `DuprIQ` — `com.jackwallner.pickleball`

## Architecture

**The app is the fleet shell plus this app's generator.** The first build
(2026-08-24) was written from scratch and had none of the shell every other
XcodeGen app in `~` inherited: no rooms, no onboarding, no feature tour, no
What's New, no daily challenge, no drill library, no session builder. On
2026-08-28 the shell was ported in from `~/electrician` (which is itself the
`~/mahj` shell already retargeted once to a generator-first app) and the
bespoke generator was grafted onto it. Read `~/electrician` when you need to
know why a shell file is shaped the way it is; read this file for what changed
on the way over.

- `Shared/Models` — `Court`, `RallyPosition`, `Shot` (bespoke); `Drill`/`Room`,
  `Given`, `Principle` (shell shape, this app's domain)
- `Shared/Content` — `PositionGenerator` (the asset) and `ShotAdvisor` (the
  rules engine), both total, deterministic and seedable; `EndlessPractice`
  (the adapter), `SessionBuilder`, `DrillLibrary`, and the authored rooms
- `Shared/Services` — progress by phase and practice history, the 15-ball free
  daily cap, `PracticeRecordStore` (item-level memory), `AppSettings`,
  `PlayerProfile`, subscriptions, review funnel, `ContentReport`, and the
  DEBUG-only `DebugFixtures` that gives screenshot runs a deterministic state
- `DuprIQ/Views` — `HomeView` lobby, `DrillSessionView` (the generated loop),
  `CourtDiagramView`, the shell's `Drills/` runners for authored content,
  rooms, onboarding, tour, primer, progress, paywall, settings

**`EndlessPractice` is the graft seam.** It turns a `DrillQuestion` into the
same `QuickItem` the authored drills emit, so the session runners never have to
know whether a question was written by hand or generated a second ago. The one
thing that could not be adapted away is the court: `QuickItem` carries an
optional `position`, and `QuestionPager` renders `CourtDiagramView` when it
finds one and a row of `Given` chips when it does not. Four sets of feet ARE
the question; flattening them into prose would delete the app.

`PositionGeneratorTests` and `ShotAdvisorTests` are the content contract.
If a generated position is off-court, the answer is missing from the
options, or a dink rally ships an attackable ball, the paid tier is
broken. Do not weaken those tests to land a generator change.
`ServiceTests` is the equivalent contract for the daily cap, the streak rule,
the accuracy sample threshold, the practice history and the review gate: none
of those regressions show up in a generator test.
`ContentTests` is the contract for everything the port brought in: that every
authored question is answerable, that the Worked Reads room cannot disagree
with the advisor, that generated balls roll up to one tracking row per phase,
and that no leftover word from the previous domains survives in the copy. It
matches on WORD BOUNDARIES, because the first version used `contains` and
failed on "tiebreaker".

**Lateral position is load-bearing.** The advisor branches on where the contact
sits relative to the center line (no long diagonal exists from the middle) and
on how far apart the two opponents are standing (an open seam beats either
body). Every generated position is mirrored with probability one half, and
`testTheAnswerIsUnchangedUnderALeftRightMirror` pins the property that makes
this a decision rather than a side: reflect the court and the shot is
identical, aimed at the marker now in the mirrored place. Any new rule has to
keep that symmetry, and any verdict that names an opponent has to carry
`targetOpponent` so the diagram can highlight the marker it means.

**One kitchen contract.** `Court.kitchenDepth` (7 ft) is the line the rulebook
and the diagram draw. `Court.kitchenReadyDepth` (8.5 ft) is how far back a
player can stand and still count as "at the line", because nobody waits inside
the non-volley zone. Generation, classification, the diagram and the tests all
use those two constants; do not introduce a third threshold.

## Products
Local StoreKit configuration (`DuprIQ/DuprIQ.storekit`):

- `com.jackwallner.pickleball.pro.monthly`, $9.99 / month, one-week trial
- `com.jackwallner.pickleball.pro.yearly`, $59.99 / year, one-week trial
- `com.jackwallner.pickleball.pro.lifetime`, $99.99 one time

This is above the Vitals default on purpose. Pickleball coaching is an
already-paying audience (lessons, not exam prep), and the DUPR-adjacent
positioning has to look like a coaching product. Change it only with an
explicit pricing pass.

The public `appl_` key ships in `SubscriptionService` behind the DEBUG
placeholder and the simulator early-return. The `sk_` secret lives in
`~/.pickleball_credentials` as `RC_SECRET_KEY`, the fleet convention that every
`scripts/rc-*.py` reads. `.env.local` still carries a gitignored copy for local
tooling; keep the two in sync or delete the copy.

**Re-run `scripts/rc-setup.py` after touching products or offerings**, then probe
with the iOS platform header. The fleet's recurring empty-offering bug (an
offering holding only Test Store products, which iOS filters out, leaving a dead
paywall on device) cannot be caught on a simulator, because a simulator never
configures RevenueCat:

```sh
curl -s -H "Authorization: Bearer appl_FgwCPdxYFGQtaPKOJeuxwZBsrNZ" \
     -H "X-Platform: ios" \
     https://api.revenuecat.com/v1/subscribers/probe-1/offerings
```

## App-specific notes
- **App Store Connect** record exists: id `6804828001`, name
  `DUPR IQ - Pickleball Drills`, version 1.0 in `PREPARE_FOR_SUBMISSION`.
  As of 2026-08-24 build 3 is attached and all three IAPs are
  `READY_TO_SUBMIT`. What remains is App Privacy in the web UI (no public API),
  then `scripts/asc-submit-for-review.py`.
  `scripts/asc-readiness.py` is the read-only check for all of that, and
  `docs/asc-submission-checklist.md` is the durable record of the web-UI-only
  answers (App Privacy, age rating, version review information) plus the
  first-IAP attachment step the API cannot do.
  Not yet released, so the review funnel still uses `requestReview()` rather
  than a write-review URL.
- **First IAPs must ship with the app version.** Run
  `scripts/asc-setup-release.py` (subscription group + the two subs), then
  `scripts/asc-create-lifetime.py`, then `scripts/asc-set-prices.py`. Prices in
  those scripts are the 9.99 / 59.99 / 99.99 set this file documents.
- **Subscription prices do not equalize; the lifetime IAP's do.** The lifetime
  non-consumable takes an `inAppPurchasePriceSchedules` post with a
  `baseTerritory`, and one call covers every territory. The two subscriptions
  take one `/subscriptionPrices` row per territory, so a single USA price
  against 175 available territories leaves them stuck in `MISSING_METADATA`
  with no clue which field is short. `scripts/asc-set-prices.py` is what fills
  the other 174, and its release-day gate refuses until 1.0.0 is
  `READY_FOR_SALE`. Pre-launch, with nothing in the wild quoting an old price,
  `--force` is the correct way past it; after launch it is not.
- **Subscription localization descriptions cap at 55 characters.** The API
  rejects a longer one with a 409 naming only `DESCRIPTION`, which is easy to
  misread as a malformed request.
- Marketing site: `docs/` (index, privacy-policy, support), mirrored to
  `jackwallner.com/ios/pickleball/` by `.github/workflows/sync-landing-page.yml`.
  Live as of 2026-08-24: the repo is public and Pages serves `/docs` on `main`,
  so `https://jackwallner.github.io/pickleball/` and its `privacy-policy` and
  `support` paths all resolve.
- **Screenshots run headlessly off the `Screenshots` scheme.**
  `DuprIQScreenshots` is a ui-testing target kept out of the `DuprIQ` scheme's
  test action on purpose, so the unit-test loop stays instant. Drive it with
  `scripts/capture-screenshots.sh <udid> <out>` (six shots) and
  `scripts/capture-paywall.sh <udid> <out>` (the paywall alone, with prices).
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
- **Do not trademark-drift.** The app is not affiliated with Dynamic Universal
  Pickleball Rating. The marketing pages carry that disclaimer; keep it, and keep
  the app out of anything that looks like reporting an official rating.
- Display name is `DUPR IQ` (`CFBundleDisplayName`). `PRODUCT_NAME` is
  `DuprIQ` so the `.app` and `TEST_HOST` have no spaces.
- Free tier is 15 graded balls per calendar day, not a lifetime cap,
  because the generator never runs out. The cap is checked in the lobby, before
  the court is drawn: discovering the paywall after reading a position is a
  bait-and-switch, and a session never promises more balls than the allowance
  can grade.
- **Only the GENERATED loop is metered.** The authored rooms are finite and two
  of them are free forever, so counting them against a daily cap would quietly
  take back what the free tier promised. The allowance covers Endless Practice,
  Today's Rally and the phase drills, all of which route through
  `start(phase:)` on `HomeView`/`EndlessPickerView` so the check happens before
  a court is drawn. `DrillSessionView` re-checks on every tap because a session
  can straddle midnight.
- **Endless Practice is not a Pro mode.** Every other training tile on Home is
  `trainingTile` (Pro-locked); the Endless tile is a plain `NavigationLink`,
  because generated practice is the free tier's entire product and the daily
  allowance is already its meter. If it ever gets a lock badge, the free tier
  has become a demo.
- **Generated misses come back as MISTAKES, not as questions.** A generated
  position's id is a one-off, so `PracticeRecordStore` rolls every ball in a
  phase onto one row and `isReviewable` is false. `MistakeCatalog` names the
  reasoning error behind each wrong shot ("you attacked a ball that was not
  above the net"), and `EndlessPractice.targetedItems` mints a NEW position of
  the right phase that sets the same trap. Replaying a court whose answer they
  now remember would test their memory, not the read that produced the miss.
- **The free/Pro line is history, not accuracy.** Accuracy by phase is free and
  visible on the lobby, so selling it back as a Pro benefit was a claim the app
  could not keep. Pro is the unlimited cap plus session history and the ranked
  missed principles. The paywall copy, `docs/index.html` and
  `fastlane/metadata/en-US/description.txt` all have to agree with that; they
  did not, and it was the audit's clearest trust problem.
- **A percentage needs a sample.** `ProgressThreshold.sampleForAccuracy` (5)
  gates when a phase shows a number at all; below it the UI shows `New` or a
  count. A streak needs `ballsForPracticeDay` (5) too, because a streak that
  starts on one tap is engagement theatre.
- **Paywall prices are real or absent.** There is no release fallback price
  string. `SubscriptionService.storeState` drives a loading, available,
  unavailable or not-configured surface, and `trialCopy(for:)` derives the trial
  line from the product's actual introductory offer and this account's
  eligibility rather than promising everyone seven free days.
- Shot selection is coached opinion. `CoachingSystemView` states the
  system (unattackable ball, get to the kitchen, hit the player who
  isn't set). Keep answers named by principle.

---
Shared iOS conventions (build, simulator, release/TestFlight, ASC key, signing,
review funnel, gotchas): always-loaded global CLAUDE.md + the `ios-dev` skill.
