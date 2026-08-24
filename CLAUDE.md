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
- `Shared/Models` — `Court`, `RallyPosition`, `Shot`
- `Shared/Content` — `PositionGenerator` (the asset) and `ShotAdvisor`
  (the rules engine). Both are total, deterministic, and seedable.
- `Shared/Services` — progress by phase, the 15-ball free daily cap,
  subscriptions, review funnel
- `DuprIQ/Views` — `TodayView` lobby, `DrillSessionView` (the loop),
  `CourtDiagramView`, progress, paywall, settings

`PositionGeneratorTests` and `ShotAdvisorTests` are the content contract.
If a generated position is off-court, the answer is missing from the
options, or a dink rally ships an attackable ball, the paid tier is
broken. Do not weaken those tests to land a generator change.

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
`.env.local` (gitignored) and never enters source.

## App-specific notes
- **Not yet on the App Store.** There is no App Store ID yet, so the
  review funnel uses `requestReview()` rather than a write-review URL.
  Set the ID in this file when the ASC record exists.
- Privacy policy: `https://jackwallner.github.io/pickleball/privacy-policy`
- Display name is `DUPR IQ` (`CFBundleDisplayName`). `PRODUCT_NAME` is
  `DuprIQ` so the `.app` and `TEST_HOST` have no spaces.
- Free tier is 15 graded balls per calendar day, not a lifetime cap,
  because the generator never runs out.
- Shot selection is coached opinion. `CoachingSystemView` states the
  system (unattackable ball, get to the kitchen, hit the player who
  isn't set). Keep answers named by principle.

---
Shared iOS conventions (build, simulator, release/TestFlight, ASC key, signing,
review funnel, gotchas): always-loaded global CLAUDE.md + the `ios-dev` skill.
