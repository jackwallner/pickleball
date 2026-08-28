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

**The app is the fleet shell plus this app's generator, played in first
person.** The first build (2026-08-24) was written from scratch and had none of
the shell every other XcodeGen app in `~` inherited. On 2026-08-28 the shell was
ported in from `~/electrician` (itself the `~/mahj` shell retargeted once
already) and the generator was grafted onto it. Later that day the whole
presentation was pivoted: the shell's flashcard shape was the problem, not the
content. Read `~/electrician` when you need to know why a shell file is shaped
the way it is; read this file for what changed on the way over and what was torn
out afterwards.

- `Shared/Models` — `CourtGeometry`, `RallyPosition`, `Shot`, `ShotTargeting`
  (bespoke); `Drill`/`Court`, `Given`, `Principle` (shell shape, this domain)
- `Shared/Content` — `PositionGenerator` (the asset) and `ShotAdvisor` (the
  rules engine), both total, deterministic and seedable; `RallyBuilder` (points,
  not balls), `EndlessPractice` (the adapter), `SessionBuilder`, `DrillLibrary`,
  and the authored courts
- `Shared/Services` — progress by phase and practice history, the 15-ball free
  daily cap, `PracticeRecordStore` (item-level memory), `AppSettings` (including
  the shot clock), `PlayerProfile`, subscriptions, review funnel,
  `ContentReport`, and the DEBUG-only `DebugFixtures`
- `DuprIQ/Views/Court3D` — the first-person court: `CourtCamera` (the eye and
  the projection), `CourtScene` (the SceneKit world), `CourtPOVView` (the
  playable view), `AimLabelLayout` (keeping the four captions apart)
- `DuprIQ/Views` — `HomeView` lobby, `DrillSessionView` (the rally loop),
  `CourtDiagramView` (the overhead, now an explanation only), the shell's
  `Drills/` runners for authored content, courts, onboarding, tour, primer,
  progress, paywall, settings

**Rooms are courts.** The shell arrived calling its four themed groups "rooms",
which is `~/mahj` vocabulary. They are `Court` now, and the geometry namespace
that used to own that name is `CourtGeometry`. Both were renamed together, in
the code and in the copy, because a codebase that disagrees with the product is
how the next person introduces a third word for the same thing.

### The first-person court

**The decision is made in 3D; the overhead is the whiteboard afterwards.** The
old loop drew a plan-view diagram, printed the two decisive facts underneath it
in words ("Below net height, hit from the right side"), and asked the player to
pick one of four sentences. That is a flashcard: reading ball height off a
caption is not the skill the app claims to train. Now `CourtPOVView` puts you on
the court, the ball hangs at an actual height beside a net whose tape is at a
known one, and the four options are RINGS on the paint where the shot would
land. `CourtDiagramView` survives inside `VerdictCard`, behind a disclosure,
which is exactly the role it should have had: the geometry a coach draws for you
after the point, not the thing you play from.

Grading did not change. A tap still resolves to an index into
`DrillQuestion.options`, so `ShotAdvisor`, `PositionGenerator` and every test
that pins them were untouched by the pivot.

**SceneKit draws the world; SwiftUI names it.** There is no text in the scene.
Player initials and the four captions are SwiftUI, positioned by projecting
court points through `CourtCamera`, so they stay crisp, honour Dynamic Type and
reach VoiceOver. `CourtCamera` owns the projection itself rather than calling
`SCNSceneRenderer.projectPoint`, and it configures the `SCNCamera` from the same
numbers: if the captions sit on the rings in a screenshot, the two agree.

**Everything in the scene is procedural.** Boxes, capsules, spheres and tori,
sized in feet from `CourtGeometry`. No models, no textures, no growth in binary
size, and no way for the rendered court to drift from the rulebook the advisor
reasons about.

**A net is a mesh, not a panel.** This cost two rebuilds. Drawn as a
semi-transparent panel it rendered as a solid black wall across the middle of
the frame and hid the opponents, and each attempted fix (alpha, blend mode,
depth writes, rendering order) looked like it should have worked. It is now
about forty thin boxes with holes between them, which physically cannot occlude.
The detour also produced a wrong camera: reasoning that a 34 inch net hides the
far kitchen from anyone at their own baseline, the eye was raised to twelve feet
to see over it, which squeezed the opponents into a thirteenth of the screen. Do
not raise the camera. You look THROUGH a net.

**The camera is fitted, not fixed.** One field of view cannot serve both ends of
the court: from your baseline everything is distant and a narrow angle is right,
while from the kitchen line an opponent at the far sideline is forty degrees off
your nose. `CourtCamera.viewing` centres the head on what has to be visible and
widens the angle until it fits, then walks the eye backwards only if widening
runs out (a pulled-back eye misrepresents how close YOU are to the kitchen,
which is itself a read). `CourtCameraTests` asserts on every phase that the
ball, both opponents and all four rings are in frame, that depth runs up the
screen and that left is left. Those are invisible failures otherwise: everything
computes, the scene renders, and the one object the question is about is simply
not there.

**Optic yellow belongs to the ball and the aim rings.** Nothing else may use it.
Your partner was painted in it and, standing a few feet from the eye, became the
largest and brightest object on screen.

### Points, not balls

`RallyBuilder` builds POINTS. A correct decision advances the same rally to your
next shot; a wrong one loses the point and skips the rest of it, the way a real
one ends. `RallyBuilderTests` pins the part that would otherwise train an
impossible sequence: the serving team never returns serve and the returning team
never hits the third shot. Metering is unchanged — every graded ball still costs
one from the daily allowance, and a session is still truncated to the allowance
rather than promising balls it cannot grade.

`AppSettings.ShotClock` is the other half. Shot selection with unlimited time to
deliberate is a different skill from shot selection, and the app was training the
wrong one; the clock defaults to match pace and a ball you did not decide about
is graded as a miss, because that is what happens on a court. `off` exists as an
accessibility escape hatch, not as the normal way to play.

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
`CourtCameraTests`, `ShotTargetingTests`, `AimLabelLayoutTests` and
`RallyBuilderTests` are the contract for the first-person pivot: what must be in
frame, where a shot lands, that four captions stay apart and tappable, and that
a point is a sequence someone could actually play. Every one of them exists
because of a failure a screenshot caught and no other test would have.
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

**One kitchen contract.** `CourtGeometry.kitchenDepth` (7 ft) is the line the
rulebook and both renderers draw. `CourtGeometry.kitchenReadyDepth` (8.5 ft) is
how far back a player can stand and still count as "at the line", because nobody
waits inside the non-volley zone. Generation, classification, the 3D scene, the
overhead and the tests all use those two constants; do not introduce a third
threshold.

**Where a shot lands is a pure function.** `ShotTargeting` maps a `Shot` to a
court point, and `ShotAiming` de-collides the four so two options can never draw
one ring on top of another (the attack phase really does offer both "Put it
away, at their feet" and "Drive, at their feet"). De-collide in COURT space
only; screen space is `AimLabelLayout`'s job, and conflating them is what made
all four captions pile into one unhittable stack at forty feet of depth. The
fan lays a cluster out around its centre and slides the whole run inside the
sidelines, because clamping each member independently collapsed the fan
whenever it sat near an edge.

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
