# DUPR IQ - App Store Connect submission checklist

The durable record of what has to be true before version 1.0 is submitted, and
of the answers to give in the parts of App Store Connect that have no public
API. `scripts/asc-finish-submission.py` points here; so does the release
runbook in `CLAUDE.md`.

App Store name: **DUPR IQ - Pickleball Drills**. On-device display name: **DUPR IQ**.
App id `6804828001`, bundle id `com.jackwallner.pickleball`.

Read-only status at any time:

```sh
python3 scripts/asc-readiness.py
```

---

## 1. Things the scripts already do

Run in this order for a first release. Each is idempotent.

| Step | Script | What it covers |
| --- | --- | --- |
| Draft version | `scripts/asc-ensure-draft-version.py` | 1.0 exists and is editable |
| Metadata | `scripts/asc-upload-metadata.py` | name, subtitle, description, keywords, promo text, support and marketing URLs |
| Subscriptions | `scripts/asc-setup-release.py` | Pro group, monthly, yearly |
| Lifetime | `scripts/asc-create-lifetime.py` | the non-consumable |
| Prices | `scripts/asc-set-prices.py` | 9.99 / 59.99 / 99.99 across all territories |
| Release prerequisites | `scripts/asc-finish-submission.py` | content rights, free app price schedule, copyright, support URL, review contact email |
| Build | `scripts/testflight.sh` | archive and upload, then attach the processed build |
| Screenshots | `scripts/capture-screenshots.sh --strict` then `scripts/asc-upload-screenshots.py` | the five iPhone shots and five iPad shots |

**Subscription prices do not equalise; the lifetime IAP's do.** One
`/subscriptionPrices` row per territory is required, which is what
`asc-set-prices.py` fills in. Pre-launch, `--force` is the correct way past its
release-day gate. After launch it is not.

**Subscription localization descriptions cap at 55 characters.** A longer one
comes back as a 409 naming only `DESCRIPTION`.

---

## 2. App Privacy (web UI only, no public API)

Published as of 2026-08-24. If it ever has to be re-entered, these are the
answers, and they are the ones the code actually supports:

- **Data collected:** Purchases only.
- **Purposes:** App Functionality.
- **Linked to the user:** No.
- **Used for tracking:** No.
- **Privacy policy URL:** `https://jackwallner.github.io/pickleball/privacy-policy`

Practice history, streaks, and progress are `UserDefaults` on the device and
never leave it. There is no analytics SDK in the project. RevenueCat receives an
anonymous purchase identifier and Apple's transaction details, which is what the
Purchases declaration covers.

If an analytics SDK, an account system, or a server-side history sync is ever
added, this section and `docs/privacy-policy.html` both have to change before
the build that adds it ships.

---

## 3. Age rating (web UI only)

Reviewed and saved 2026-08-24 on the current questionnaire. Every capability
question is **No**: no social media, no messaging or chat, no user-generated
content, no advertising, no gambling, no contests, no unrestricted web access.
Resulting rating: **4+**.

---

## 4. Version review information (web UI only)

Version 1.0 review information was saved as of 2026-08-26. The sign-in
checkbox is off, the reviewer notes are saved, and the contact fields are
complete:

- **Sign-in required: OFF.** The app has no account and no login screen. Leaving
  the checkbox on hands App Review an impossible credential requirement, and it
  is enough on its own to fail the submission.
- **First name / last name:** the account holder.
- **Phone number:** the fleet review contact, saved in App Store Connect.
- **Email:** the release contact in `scripts/asc-finish-submission.py`, saved in
  App Store Connect.
- **Notes:** something close to this, which describes the real reviewer path:

  > No account or login is required. Open the app, tap "Today's rally" on the
  > Practice tab, and answer any of the four shot options to see a graded ball
  > and the coaching principle behind the answer. The free tier allows 15
  > graded balls per calendar day. To see the purchase surface without buying,
  > go to Settings and tap "See Pro"; Restore Purchases is on the same screen
  > and on the paywall. All practice data is stored locally on the device.

The saved sign-in setting, notes, and contact fields were confirmed through the
browser after reloading the version page. The ASC page no longer shows a review
blocker for contact information, screenshots, or App Privacy.

The version item was prepared through the API without submitting it:

```sh
python3 scripts/asc-readiness.py
python3 scripts/asc-submit-for-review.py --dry-run
```

The dry run attaches version 1.0 without submitting it.

---

## 5. First in-app purchases must ship with the version

The API reporting all three products as `READY_TO_SUBMIT` is **not** the same as
their being attached to the review submission. On a first release, ASC requires
the first subscription group and the first non-consumable to be added to the
app version's submission by hand. Completed 2026-08-25. The draft submission
contains all four items:

- [x] Subscription group **Pro**
- [x] `com.jackwallner.pickleball.pro.monthly`
- [x] `com.jackwallner.pickleball.pro.yearly`
- [x] `com.jackwallner.pickleball.pro.lifetime`

Re-run readiness and the dry run afterwards and confirm all four appear in the
submission.

---

## 6. Screenshots

Capture from the deterministic fixture, never from whatever the simulator was
holding. The demo fixture and the pinned drill seed are what make a re-run
produce the same asset:

```sh
UDID=$(agent-sim checkout pickleball | tail -1)
./scripts/capture-screenshots.sh --strict "$UDID" build/shots
python3 scripts/asc-upload-screenshots.py --locale en-US --version 1.0
agent-sim checkin pickleball
```

`--strict` is the release gate: without it a missing control is collected as a
diagnostic note and the run still reports success, which is how an iPad set was
once uploaded from a run whose only output said "no Practice tab".

The set is, in order: the practice lobby, the court question, the graded answer
with its principle, progress by phase, and the paywall. The sixth capture (the
first-run court primer) is a spare.

**iPad:** version 1.0 ships universal. The target uses
`TARGETED_DEVICE_FAMILY "1,2"`, so upload the 13-inch iPad set alongside the
iPhone set.

---

## 7. Release day

- [ ] Swap the "Coming to the App Store" block in `docs/index.html` for the real
      link, `https://apps.apple.com/app/id6804828001`. The URL 404s until 1.0 is
      Ready for Sale.
- [ ] Switch the review funnel from `requestReview()` to a write-review URL now
      that one exists (`ReviewPromptTracker` / `EnjoymentGateSheet`).
- [ ] Re-run `scripts/asc-set-prices.py` without `--force` and confirm its
      release-day gate passes on its own.

---

## 8. Do not submit until

- [x] `scripts/asc-readiness.py` is clean.
- [x] Version review information is saved, with sign-in **off** and a real phone
      number.
- [x] All four IAP items are attached to the submission.
- [x] Screenshots came from a `--strict` capture run.
- [x] The iPad decision above is made and acted on.
- [x] `scripts/asc-submit-for-review.py --dry-run` attaches version 1.0.
- [x] The app has been run from a reset simulator state and the reviewer path in the
      notes above actually works.
