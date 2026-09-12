---
paths:
  - "Shared/Services/PracticeLimiter.swift"
  - "Shared/Services/ProgressStore.swift"
  - "Shared/Services/PracticeRecordStore.swift"
  - "Shared/Services/SubscriptionService.swift"
  - "Shared/Content/EndlessPractice.swift"
  - "DuprIQ/Views/HomeView.swift"
  - "DuprIQ/Views/EndlessPickerView.swift"
  - "DuprIQ/Views/DrillSessionView.swift"
  - "DuprIQ/Views/PaywallView.swift"
  - "DuprIQ/Views/ProgressDashboardView.swift"
  - "docs/index.html"
  - "fastlane/metadata/en-US/description.txt"
  - "DuprIQTests/ServiceTests.swift"
---

# DUPR IQ: the free tier and Pro

Moved verbatim from CLAUDE.md. Loads when a matching file is read; update it here.

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
