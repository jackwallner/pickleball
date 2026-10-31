---
paths:
  - "Shared/Services/PracticeLimiter.swift"
  - "Shared/Services/MasteryStore.swift"
  - "Shared/Services/LegacyReminders.swift"
  - "Shared/Services/SubscriptionService.swift"
  - "DuprIQ/Views/RallyView.swift"
  - "DuprIQ/Views/YourGameView.swift"
  - "DuprIQ/Views/PaywallView.swift"
  - "docs/index.html"
  - "fastlane/metadata/en-US/description.txt"
  - "DuprIQTests/ServiceTests.swift"
---

# Third Shot: the free tier and Pro

- Free is 15 graded balls per calendar day, not a lifetime cap, because the
  generator never runs out. `RallyView.build` checks the allowance before a run
  is drawn and sizes the run to it; `select`/`advance` re-check on every tap
  because a run can straddle midnight. Discovering the paywall after reading a
  position is a bait-and-switch.

- **The free/Pro line is history, not learning.** Replays, focus points and
  principle mastery are free. Pro is the unlimited cap plus the ranked traps and
  the run history in "Your game". The paywall benefits, `docs/index.html` and
  `fastlane/metadata/en-US/description.txt` must agree.

- **A percentage needs a sample.** `MasteryThreshold.sample` (5) gates when a
  principle shows a number; below it the row shows `New` or `n of 5`. A streak
  day needs `ballsForPracticeDay` (5) balls.

- **Paywall prices are real or absent.** There is no release fallback price
  string. `SubscriptionService.storeState` drives a loading, available,
  unavailable or not-configured surface, and `trialCopy(for:)` derives the trial
  line from the product's actual introductory offer and this account's
  eligibility.

- Buying Pro from the free-limit summary starts a new run immediately
  (`RallyView` watches `isPro`).

- **Days are counted by date, never by hours.** `MasteryStore.daysBetween`
  reads each date's year, month and day and subtracts them at noon UTC.
  `dateComponents([.day])` between two starts of day reads zero days where
  clocks go forward at midnight (Santiago, Havana, Cairo, Beirut, the Azores:
  the day starts at 01:00, 23 hours before the next one), and
  `ordinality(of: .day, in: .era)` returned the same day for 29 and 30 March in
  London on macOS 12, so neither is safe. `ServiceTests` walks every time zone's
  2026 clock changes. The dates are read off the Gregorian calendar in the
  device's time zone, whatever calendar the device uses: the Chinese calendar
  numbers a leap month like the month before it, so consecutive days read 29 or
  31 apart at either end of it (`ServiceTests` pins both ends in 2025).

- **`LegacyReminders` is the other half of deleting the shell.** Builds before
  1.1 scheduled a repeating daily reminder and a weekly warm-up. iOS keeps
  scheduled notifications across an update, so `RootView` cancels those two
  identifiers at launch. A future reminders feature must use different ones.
