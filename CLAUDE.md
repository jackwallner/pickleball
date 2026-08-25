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
  `scripts/asc-readiness.py` is the read-only check for all of that.
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
  `scripts/capture-screenshots.sh <udid> <out>` (five App Store shots) and
  `scripts/capture-paywall.sh <udid> <out>` (the paywall alone, with prices).
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
  because the generator never runs out.
- Shot selection is coached opinion. `CoachingSystemView` states the
  system (unattackable ball, get to the kitchen, hit the player who
  isn't set). Keep answers named by principle.

---
Shared iOS conventions (build, simulator, release/TestFlight, ASC key, signing,
review funnel, gotchas): always-loaded global CLAUDE.md + the `ios-dev` skill.
