# DUPR IQ Project Guide

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
- `DuprIQ`: `com.jackwallner.pickleball`

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

- `Shared/Models`: `CourtGeometry`, `RallyPosition`, `Shot`, `ShotTargeting`
  (bespoke); `Drill`/`Court`, `Given`, `Principle` (shell shape, this domain)
- `Shared/Content`: `PositionGenerator` (the asset) and `ShotAdvisor` (the
  rules engine), both total, deterministic and seedable; `RallyBuilder` (points,
  not balls), `EndlessPractice` (the adapter), `SessionBuilder`, `DrillLibrary`,
  and the authored courts
- `Shared/Services`: progress by phase and practice history, the 15-ball free
  daily cap, `PracticeRecordStore` (item-level memory), `AppSettings` (including
  the shot clock), `PlayerProfile`, subscriptions, review funnel,
  `ContentReport`, and the DEBUG-only `DebugFixtures`
- `DuprIQ/Views/Court3D`: the first-person court: `CourtCamera` (the eye and
  the projection), `CourtScene` (the SceneKit world), `CourtPOVView` (the
  playable view), `AimLabelLayout` (keeping the four captions apart)
- `DuprIQ/Views`: `HomeView` lobby, `DrillSessionView` (the rally loop),
  `CourtDiagramView` (the overhead, now an explanation only), the shell's
  `Drills/` runners for authored content, courts, onboarding, tour, primer,
  progress, paywall, settings

**Rooms are courts.** The shell arrived calling its four themed groups "rooms",
which is `~/mahj` vocabulary. They are `Court` now, and the geometry namespace
that used to own that name is `CourtGeometry`. Both were renamed together, in
the code and in the copy, because a codebase that disagrees with the product is
how the next person introduces a third word for the same thing.

## Rules that hold everywhere
Condensed from the deep notes below; the reasoning and the bugs behind each one live there.
- `PositionGeneratorTests` and `ShotAdvisorTests` are the content contract. Do not weaken them to land a generator change.
- Any new advisor rule must keep left-right mirror symmetry (`testTheAnswerIsUnchangedUnderALeftRightMirror`), and a verdict that names an opponent carries `targetOpponent`.
- Two kitchen constants only: `CourtGeometry.kitchenDepth` (7 ft) and `CourtGeometry.kitchenReadyDepth` (8.5 ft). Do not introduce a third threshold.
- In the 3D court: do not raise the camera (you look through the net), and optic yellow belongs to the ball and the aim rings only.
- Accessibility identifiers go on the control, never on a container: SwiftUI hands a container's identifier down to every view inside it.
- The free tier is 15 graded balls per calendar day, metered on the generated loop only and checked in the lobby before a court is drawn. Endless Practice is never Pro-locked.
- Pro is the unlimited cap plus session history and the ranked missed principles, not accuracy. The paywall copy, `docs/index.html` and `fastlane/metadata/en-US/description.txt` must agree.
- Paywall prices are real or absent: there is no release fallback price string.
- Prices sit above the Vitals default on purpose; change them only with an explicit pricing pass. Re-run `scripts/rc-setup.py` after touching products or offerings, then probe offerings with `X-Platform: ios`.
- App Store Connect record `6804828001`. For its current state run `scripts/asc-readiness.py`; the notes below are dated snapshots.

## Deep notes (load on demand)
These files load automatically when you read a file matching their `paths:`. Agents that do not auto-load rules (Codex, Cursor) should open the file for the area they are touching. Record new area-specific learnings in the matching file, not here.

| File | Sections | Read when |
|---|---|---|
| `.claude/rules/court-3d.md` | The first-person court; Where a shot lands is a pure function; SceneKit accessibility | `Court3D`, the camera, captions, shot targeting |
| `.claude/rules/rally-and-sessions.md` | Points, not balls (the rally, the shot clock, every mode draws the same court) | Session runners, `RallyBuilder`, the decision timer |
| `.claude/rules/generator-and-advisor.md` | `EndlessPractice` is the graft seam; the test contracts; a contact is a reach; lateral position; one kitchen contract | `PositionGenerator`, `ShotAdvisor`, content tests |
| `.claude/rules/products-and-revenuecat.md` | Products | StoreKit config, RevenueCat keys and offerings |
| `.claude/rules/release-and-asc.md` | The ASC record, first IAPs, subscription prices, localization limits, the marketing site | ASC scripts, submission, pricing scripts, `docs/` |
| `.claude/rules/screenshots-and-ui-tests.md` | The `Screenshots` scheme, identifiers, the audit tool, fixtures, `--strict`, simulator paywall prices, `setUp` isolation | Screenshot capture, UI tests, `DebugFixtures` |
| `.claude/rules/free-tier-and-pro.md` | The daily cap, what is metered, Endless Practice, mistakes, the free/Pro line, sample thresholds, real prices | `HomeView`, the limiter, progress, the paywall |

## App-specific notes
- **Do not trademark-drift.** The app is not affiliated with Dynamic Universal
  Pickleball Rating. The marketing pages carry that disclaimer; keep it, and keep
  the app out of anything that looks like reporting an official rating.
- Display name is `DUPR IQ` (`CFBundleDisplayName`). `PRODUCT_NAME` is
  `DuprIQ` so the `.app` and `TEST_HOST` have no spaces.
- Shot selection is coached opinion. `CoachingSystemView` states the
  system (unattackable ball, get to the kitchen, hit the player who
  isn't set). Keep answers named by principle.

---
Shared iOS conventions (build, simulator, release/TestFlight, ASC key, signing,
review funnel, gotchas): the global agent rules + the `ios-dev` skill.
