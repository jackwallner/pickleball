# Third Shot Project Guide

Pickleball shot selection on a first-person 3D court: a generated rally
position, four places to hit it, a replay of your shot against the right one,
and the named principle behind the answer. Formerly "DUPR IQ" (renamed
2026-10-21; see `.claude/rules/release-and-asc.md`). XcodeGen project/scheme:
`DuprIQ` (internal names kept), sim lease owner `pickleball`. Bundle ID
`com.jackwallner.pickleball`. The product name lives in `AppBrand` plus
`CFBundleDisplayName`.

## Why this app exists

Jack asked for a pickleball trainer that grades the optimal hit and placement
from the situation and the four players' feet. The generator is the product: it
never runs out, every position is physically legal, and every answer names the
principle it came from. Store name `Third Shot Pickleball Strategy`, subtitle
`Court Position and Tactics` (ASO research 2026-10-21: strategy and tactics are
the weakest-competition head terms; avoid IQ, Drills, Trainer in the name).

## Tech Stack
- Swift 6 / SwiftUI (strict concurrency)
- XcodeGen (`project.yml`). Targets: iOS 17+, `DuprIQTests`
- RevenueCat entitlement `pro`, membership brand `AppBrand.proName`

## Architecture

**The court is the app.** 1.0 was the fleet shell (lobby, flashcards, quizzes,
tour, how-to-play, what's new) with this generator grafted on, and App Review
rejected it under 4.3(a) as too similar to Jack's other apps. 1.1 deleted the
shell. Launch goes onboarding (once) then straight onto the court; there is no
lobby and no tab bar. Do not port shell screens back in from `~/electrician` or
`~/mahj`.

- `DuprIQ/Views/RallyView.swift`: the whole loop. Runs of 12 balls built by
  `RallyBuilder`, the HUD, `VerdictCard` (replay + next), `RallySummaryView`
- `DuprIQ/Views/Court3D`: `CourtCamera`, `CourtScene` (incl. `replayNode`),
  `CourtPOVView` (plays `replay` when `replayToken` changes), `AimLabelLayout`
- `OnboardingView` (court, level, side), `YourGameView` (principle mastery free;
  ranked traps and run history Pro), `SettingsView` (+ `CoachingSystemView`),
  `PaywallView`
- `Shared/Content`: `PositionGenerator` and `ShotAdvisor` (total, deterministic,
  seedable), `RallyBuilder` (points, focus points, side orientation),
  `MistakeCatalog` (named traps), `AppBrand`
- `Shared/Models`: `CourtGeometry`, `RallyPosition`, `Shot`, `ShotTargeting`,
  `ShotFlight` (pure replay paths), `Principle` (families + verdict mapping)
- `Shared/Services`: `MasteryStore` (one Codable blob: principle and phase
  accuracy, trap tallies, streak, runs), `PracticeLimiter`, `PlayerProfile`,
  `AppSettings`, `SubscriptionService`, `ConversionDiagnostics`,
  `ReviewPromptTracker`, DEBUG `DebugFixtures`

## Rules that hold everywhere
Condensed from the deep notes below; the reasoning and the bugs behind each one live there.
- `PositionGeneratorTests` and `ShotAdvisorTests` are the content contract. Do not weaken them to land a generator change.
- Any new advisor rule must keep left-right mirror symmetry (`testTheAnswerIsUnchangedUnderALeftRightMirror`), and a verdict that names an opponent carries `targetOpponent`.
- Two kitchen constants only: `CourtGeometry.kitchenDepth` (7 ft) and `CourtGeometry.kitchenReadyDepth` (8.5 ft). Do not introduce a third threshold.
- In the 3D court: do not raise the camera (you look through the net), and optic yellow belongs to the ball and the aim rings only.
- Accessibility identifiers go on the control, never on a container: SwiftUI hands a container's identifier down to every view inside it.
- The free tier is 15 graded balls per calendar day, checked before a run is built (`RallyView.build`) and re-checked on every tap. Playing is never Pro-locked.
- Pro is the unlimited cap plus run history and the ranked traps, not mastery or replays. The paywall copy, `docs/index.html` and `fastlane/metadata/en-US/description.txt` must agree.
- Every verdict principle string needs a `Principle.family` entry (`ProductContractTests`), and at most two options share a shot shape.
- Paywall prices are real or absent: there is no release fallback price string.
- Prices sit above the Vitals default on purpose; change them only with an explicit pricing pass. Re-run `scripts/rc-setup.py` after touching products or offerings, then probe offerings with `X-Platform: ios`.
- App Store Connect record `6804828001`. For its current state run `scripts/asc-readiness.py`; the notes below are dated snapshots.

## Deep notes (load on demand)
These files load automatically when you read a file matching their `paths:`. Agents that do not auto-load rules (Codex, Cursor) should open the file for the area they are touching. Record new area-specific learnings in the matching file, not here.

| File | Sections | Read when |
|---|---|---|
| `.claude/rules/court-3d.md` | The first-person court; Where a shot lands is a pure function; SceneKit accessibility | `Court3D`, the camera, captions, shot targeting |
| `.claude/rules/rally-and-sessions.md` | Points, not balls; focus points; side orientation; the replay | `RallyView`, `RallyBuilder`, `ShotFlight`, the decision timer |
| `.claude/rules/generator-and-advisor.md` | `EndlessPractice` is the graft seam; the test contracts; a contact is a reach; lateral position; one kitchen contract | `PositionGenerator`, `ShotAdvisor`, content tests |
| `.claude/rules/products-and-revenuecat.md` | Products | StoreKit config, RevenueCat keys and offerings |
| `.claude/rules/release-and-asc.md` | The ASC record, first IAPs, subscription prices, localization limits, the marketing site | ASC scripts, submission, pricing scripts, `docs/` |
| `.claude/rules/screenshots-and-ui-tests.md` | The `Screenshots` scheme, identifiers, the audit tool, fixtures, `--strict`, simulator paywall prices, `setUp` isolation | Screenshot capture, UI tests, `DebugFixtures` |
| `.claude/rules/free-tier-and-pro.md` | The daily cap, traps, the free/Pro line, sample thresholds, real prices | `RallyView`, the limiter, `MasteryStore`, the paywall |

## App-specific notes
- **Do not trademark-drift.** The app is not affiliated with Dynamic Universal
  Pickleball Rating or any rating body (`AppBrand.disclaimer`); never ask for,
  calculate or report a rating.
- `PRODUCT_NAME` stays `DuprIQ` so the `.app` and `TEST_HOST` have no spaces;
  only user-visible strings carry the brand.
- Shot selection is coached opinion. `CoachingSystemView` states the system
  (unattackable ball, get to the kitchen, hit the player who isn't set). Keep
  answers named by principle.

---
Shared iOS conventions (build, simulator, release/TestFlight, ASC key, signing,
review funnel, gotchas): the global agent rules + the `ios-dev` skill.
