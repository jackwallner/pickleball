---
paths:
  - "scripts/asc-*.py"
  - "scripts/asc-*.sh"
  - "fastlane/**/*"
  - "docs/*.html"
  - "docs/asc-submission-checklist.md"
  - ".github/workflows/*"
---

# DUPR IQ: App Store Connect and the marketing site

Moved verbatim from CLAUDE.md. Dated state here is a snapshot: run `scripts/asc-readiness.py` before trusting it. Loads when a matching file is read; update it here.

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
  those scripts are the 9.99 / 59.99 / 99.99 set documented in `products-and-revenuecat.md`.

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
