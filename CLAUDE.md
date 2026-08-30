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

**A net is a mesh, not a panel, and the mesh has to be a haze.** This cost three
rebuilds. Drawn as a semi-transparent panel it rendered as a solid black wall
across the middle of the frame and hid the opponents, and each attempted fix
(alpha, blend mode, depth writes, rendering order) looked like it should have
worked. Rebuilt as thin boxes with holes between them it still read as a
chain-link fence across the opponents' legs: cords thin enough to be cords
render near black under a physically-based material whatever colour they are
given, and forty of them at that distance close up. They are `.constant` lit,
grey-green, 42% opaque, `writesToDepthBuffer = false`, and spaced 1.5 ft by
0.7 ft. The detour also produced a wrong camera: reasoning that a 34 inch net
hides the far kitchen from anyone at their own baseline, the eye was raised to
twelve feet to see over it, which squeezed the opponents into a thirteenth of
the screen. Do not raise the camera. You look THROUGH a net.

**The ball is measured against a bar, not against the net.** The app's whole
claim is that "can I attack this" is something you SEE, and for one build it
was not: the net is twenty-five feet away and the ball is at your shoulder, so
comparing their heights across that much perspective is guesswork and players
were back to reading the caption. `CourtScene.ball` draws a white bar at exactly
net height on the ball's own drop line, with the pole carried up through it when
the ball is lower. Ball above the bar is a ball you can hit down on, and nothing
writes that down. Two earlier shapes were wrong and both are instructive: a
torus of net-tape radius projects as a four-hundred-pixel ellipse lying across
the near court, and a smaller disc still reads as a puck on the paint, because a
disc seen from above is a disc. Only a bar reads as a height.

**The camera is framed on the four rings this question draws.** It used to be
framed on a synthetic region covering every place any option could ever land,
which spanned most of the far court on every ball, so the fit ran into its
widest allowed angle every time and pinned both opponents and all four rings
into a band across the top fifth of the screen. `CourtCamera.viewing` takes the
aim points; `CourtCamera.viewing(_ question:)` computes them. It frames the
whole RING, not the point a shot lands on, because a ring is nearly two feet
across and the outermost option was being sliced off by the edge of the screen.

**Composition is a contract, not taste.** `CourtCameraTests` now asserts that
the opponents are not jammed against the top or bottom of the frame and that
every ring leaves room under it for its caption. Containment tests all passed
while the screen was unreadable; only a screenshot caught it, which is exactly
the kind of failure this file exists to stop recurring.

**The eye is a step back and a shade low.** 8.5 ft behind your stance at 5.2 ft,
not 1.6 ft at 5.9. From a head on a body, a ball on your shoetops sits forty
degrees below the horizon while the opponents sit on it, and the frame has to
stretch across both with a third of the screen of empty near court in between.
`CourtScene.stanceRing` draws a quiet ring where you are standing so the read
the old close eye protected, how close YOU are to the kitchen, is a thing you
can see. Quiet is the operative word: the first version had a bright ring and a
vertical stake eight feet from the lens and became a fifth glowing target on our
own side of the net.

**The captions go BELOW their rings.** Lifted above them, on a portrait phone,
all four pills landed on the far court and covered both opponents' bodies and
most of the rings they named: the render was hiding the four sets of feet the
question is about. The near court below is empty by construction.
`CourtPOVView.verdictBandHeight` reserves the strip the verdict card will cover
so the captions are laid out clear of it and nothing reflows when a ball is
graded. That reserve is a cap in POINTS, not a fraction: 40% of a 13 inch iPad
is 546 points held for a card that is never taller than 330.

**A caption says the shot shape, unless two options share one.** The place is
the ring, and printing "cross-court kitchen" on a pill sitting on the
cross-court kitchen hands back the answer. But the third shot routinely offers a
drive at their feet AND a drive down the line, which captioned by shape alone is
two identical pills and a question nobody can answer. `ShotAiming.captions`
adds the place only where it is the thing telling two options apart, and
`ShotTargetingTests` pins that no two options ever caption identically.

**The camera is fitted, not fixed.** One field of view cannot serve both ends of
the court: from your baseline everything is distant and a narrow angle is right,
while from the kitchen line an opponent at the far sideline is forty degrees off
your nose. `CourtCamera.viewing` centres the head on what has to be visible and
widens the angle until it fits, then walks the eye backwards only if widening
runs out. `CourtCameraTests` asserts on every phase that the ball, the net-height
bar beside it, both opponents and all four rings are in frame and not jammed
against an edge, that depth runs up the screen and that left is left. Those are invisible failures otherwise: everything
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

`AppSettings.ShotClock` adds pressure after the player understands the court read.
Generated practice defaults to untimed because a beginner first has to learn the
ball, feet, rings, and labels. Settings exposes an off-by-default Decision Timer;
enabling it starts at a nine-second learning pace, with game and fast options after
that. When enabled, a ball the player does not decide about is graded as a miss.

**Every mode that plays a generated ball draws the same court.** The pivot
changed `DrillSessionView` and `QuickSessionView` and missed `PracticeRunView`,
so Timed Challenge and Fix My Mistakes, both Pro-locked, went on serving the
overhead diagram above a list of sentences that the pivot had replaced
everywhere else. The fix was one call site: `QuestionPager` already renders
`CourtPOVView` when it is handed `shots`, and that runner was not handing them
over. `CourtPOVView.Chrome` is what makes the same view work in both places: a
full-bleed drill reserves the HUD band and the verdict card's strip and draws
your paddle, an embedded 340 point card reserves almost nothing, shrinks the
captions, and culls the paddle (in a card it is a dark notch in the corner that
reads as a clipping artefact). `EndlessPractice.prompt` lost its ball height and
contact side at the same time: correct copy above an overhead diagram, a
giveaway printed over a render whose whole job is to make you read them.

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
frame AND where in the frame, where a shot lands, that four captions stay apart,
below their rings and distinguishable from each other, and that a point is a
sequence someone could actually play. Every one of them exists
because of a failure a screenshot caught and no other test would have.
`ContentTests` is the contract for everything the port brought in: that every
authored question is answerable, that the Worked Reads room cannot disagree
with the advisor, that generated balls roll up to one tracking row per phase,
and that no leftover word from the previous domains survives in the copy. It
matches on WORD BOUNDARIES, because the first version used `contains` and
failed on "tiebreaker".

**A contact is a reach from a stance.** `you` and `contact` used to be
independent draws, which routinely put the ball eight feet to the side of the
feet supposed to be hitting it. A plan-view diagram drew that as two dots near
each other; in first person it is a ball fifty degrees off your nose that no
human could reach, and it was the one generator bug the overhead view was
hiding. `PositionGenerator.contactPoint` derives the contact from `you` as a
reach, signed forward offset per phase (in front at the kitchen, late and low on
defense), and `partnerPoint` puts your partner across the center line from you
instead of, sometimes, inside your own head.

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
- **An identifier on a container beats the ones inside it.** `answer-card` was
  applied to the whole `VerdictCard`, and SwiftUI handed it down to every view
  in the card: the primary button reported `answer-card` and `next-ball` did not
  exist anywhere in the tree, so every capture run walked exactly one ball and
  reported success. Identifiers go on the control, before the layout modifiers.
- **SceneKit publishes an accessibility element per node.** The court exported
  roughly two hundred unlabelled elements (forty net strands, every line box,
  both players' limbs); VoiceOver had to be swiped through all of it and
  XCUITest queries slowed to the point of timing out. `.accessibilityHidden` on
  the SwiftUI wrapper does not reach inside a hosted `UIView`, so `SCNView`
  gets `accessibilityElementsHidden` directly.
- **`DuprIQScreenshots/AuditTests` is the audit tool, not part of the set.** It
  walks the real loop slowly enough for a host-side `simctl io screenshot` loop
  to record it. That is how the framing failures above were found; none of them
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
