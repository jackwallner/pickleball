# State machine audit, 2026-11-24

Scope: the Third Shot iOS app (one app target, `DuprIQ`). It has no widgets,
no Watch app, no App Intents and schedules no notifications (the only
notification code, `LegacyReminders`, cancels two identifiers 1.0 builds
left behind). Audited from committed code at `f17ae53`. No app code was
changed in this phase.

**Summary: 2 bugs proved by failing test, 0 code path only.** Both come from
one root cause (a calendar date stored as a start-of-day instant). Plus 8
product calls, not counted.

Evidence run: `gh-sim test --scheme DuprIQ --only DuprIQTests/StateMachineAuditRepro`
on the starting code, run `pickleball@20261125-093544-735c-claude-imacef26-1125-094201-17773` (GitHub Actions run 45667509429, Xcode 27.1, iPhone 17, iOS 27.2). Result: 4 tests, 2 passed (the controls), 2 failed (the claims). The failure strings below are the recorded first failing assertion of each test; assertions after it have no recorded result and are not claimed. The repro
suite is `state-machines-2026-11-24-repro.swift` beside this file (copy it into
`DuprIQTests/` to run it).

Test seams used: `MasteryStore(defaults:calendar:)` with a pinned Gregorian
calendar per zone, `record(_:picked:focus:on:)` and `rollOverIfNeeded(now:)`
with explicit dates, and `load(_:)` to hand one store's state to a store on
another zone's calendar without a rollover. That is how a time zone change
happens on a phone: the shared store stays resident and `Calendar.current`
changes zone under it. Seams that do not exist: a constructible `CustomerInfo`
(RevenueCat is not injected into `SubscriptionService`) and a host for
`RallyView`'s `@State`. Entitlement and run-flow items therefore stay product
calls unless a pure function covers them.

## Bugs ranked by impact

| ID | Bug | What the user sees | Promise | User route | Impact | Evidence | file:line |
|---|---|---|---|---|---|---|---|
| B1 | A westward time zone change ends the streak | A player who practiced yesterday in New York opens the app in Los Angeles today: "Your game" shows a 0-day streak, and today's practice starts it again at 1 instead of 2. | `MasteryStore.swift:217-218` doc comment: "Calendar days from `earlier` to `later`, counted by date and not by hours." `.claude/rules/free-tier-and-pro.md`: "Days are counted by date, never by hours." The streak tile, `YourGameView.swift:57` ("day streak"). | Play 5 or more balls on day D (a practice day). Travel west, or change the device's time zone to any zone west of the one you played in. On day D+1 local, open the app: `App.swift` `onAppear`/scene active runs `mastery.rollOverIfNeeded()`, which reads D's stored midnight as D-1 in the new zone, finds a 2-day gap and zeroes the streak. Play 5 balls: `updateStreak` sees the same 2-day gap and sets 1. | Every player who practices across a westward zone change on consecutive days: travel to a tournament or a holiday, any distance (one zone is enough: Chicago's midnight is 23:00 the day before in Denver). Eastward changes are safe. Cost: a streak the player earned, the number "Your game" leads with, lost with no way to restore it. | Test: `testAStreakSurvivesAWestwardTimeZoneChange`. Preconditions asserted first (streak 1 in New York; the same state reads streak 1 in Los Angeles). Failed with `("0") is not equal to ("1") - 11 September is the day after the last practice day; the streak is not over`. Control `testControlAStreakAcrossTwoDaysInOneZone` passed (1, then 2). | `MasteryStore.swift:193,205-215` (stores `startOfDay`), `:241-249` (rollover), `:226-237` (`daysBetween` reads the stored instant in the current zone) |
| B2 | A westward time zone change mid-day restarts today's ball count | A player plays 3 balls in New York, flies to Los Angeles and plays 2 more the same date: the day does not count toward the streak, because today's count restarted at 1. | Same promise as B1. `MasteryThreshold.ballsForPracticeDay` doc: "Balls in one calendar day before that day counts toward the streak." (`MasteryStore.swift:7`) | Play fewer than 5 balls on day D, change to a zone to the west while still on date D, play the rest. `countTowardToday` compares the stored New York midnight (21:00 on D-1 in Los Angeles) with today's start of day, finds a different day and restarts the count. | Players who split one day's practice across a westward zone change (a travel day). Narrower than B1. Cost: a practice day lost, which can end a streak (B1's cost). | Test: `testTodaysBallsSurviveAWestwardTimeZoneChange`. Preconditions: 3 balls counted, streak 0 in New York. Failed with `("2") is not equal to ("5") - all five balls were played on 10 September`. Control `testControlTodaysBallsInOneZone` passed (5 balls, streak 1). | `MasteryStore.swift:192-203` |

## Product calls (not counted: documented, or no cited promise)

1. **Side and level apply from the next run.** Changing Side in Settings
   (reached from "Your game" over the court) does not re-mirror the balls
   already built for the run on screen (`RallyView.build`, `RallyBuilder.session(half:)`).
   The shot clock does apply mid-ball, and that is the only setting the rules
   promise applies at once. Rebuilding mid-run would throw away the score.
2. **The daily allowance has the same instant-for-a-date shape.**
   `PracticeLimiter` stores `startOfDay` (`PracticeLimiter.swift:57-68`). A
   westward change on the same date resets `usedToday` to 0, so the player gets
   a second 15 balls that day. It favours the player and costs Jack a handful of
   free balls; changing it would take balls away from someone mid-trip.
3. **The old rating ask could land over a sheet.** `RallyView.endRun` waited
   1.4 s and checked only `finished`, so "See Pro" at the free-limit summary or
   "Your game" opened in that window got the prompt over it, and the free-limit
   summary (the Pro pitch) was itself a trigger. Superseded by Rollout S, which
   rewrote the trigger; not counted here.
4. **A pending Ask to Buy read as a red RevenueCat error** on the paywall.
   Rollout A covers it; not counted here.
5. **Intro eligibility is read once per offerings load**
   (`SubscriptionService.loadIntroEligibility`) and not refreshed after a
   purchase, so trial wording can be stale in a process that saw a lapse.
6. **`isPro` is not persisted** (`SubscriptionService.swift`). An offline cold
   launch relies on RevenueCat's cached customer info reaching `refreshCustomerInfo`.
   The SDK caches it; not verified here.
7. **The streak tile is not rolled over by a midnight in the foreground.**
   `MasteryStore.rollOverIfNeeded` runs on appear and on scene active, not on
   `NSCalendarDayChanged` (the limiter does). A player who leaves the app open
   across two midnights without playing sees yesterday's streak until the next
   foreground. Display only, rare, and the next ball recomputes it.
8. **Paywall Restore is not disabled during a purchase.** Both share
   `isWorking`; Restore stays tappable while Apple's sheet is up. No promise
   cited, and StoreKit serializes the two.

## State machines

### SM1. Entitlement and purchase (`SubscriptionService`)

State: `isConfigured`, `isPro`, `offerings`, `storeState`
(loading / available / unavailable / notConfigured), `introEligibility`, the
DEBUG local override.

Invariants: E1 `isPro` equals the `pro` entitlement after every `apply`
(plus the DEBUG override); E2 a price shown is a real product's price or
absent; E3 a trial is promised only to an eligible account (`trialCopy`).

| From | Event | To | Invariant |
|---|---|---|---|
| not configured | `start()` on device with the `appl_` key | configured, loading | none |
| loading | offerings arrive with packages | available | E2 |
| loading | offerings empty or fail | unavailable, paywall shows the not-reachable card | E2 |
| Free | purchase ok, entitlement active | Pro, conversion recorded | E1 |
| Free | purchase ok, entitlement late | Free, `confirmEntitlement` polls 3 times, then a "Tap Restore" line | E1 |
| Free | user cancels Apple's sheet | Free, no error | none |
| Free | Ask to Buy (`paymentPendingError`) | Free, red English error (product call 4, Rollout A) | none |
| Free (pending) | parent approves, delegate fires | Pro | E1 |
| Pro | lapse seen on foreground refresh | Free | E1 |
| any | restore ok | Pro or "No previous purchase found" | E1 |

### SM2. Daily allowance (`PracticeLimiter`, `RallyView`)

State: `usedToday`, stored `limiter.day`. Checked in `RallyView.build`
(run sized to the allowance), re-checked in `select`, `advance` and `expire`.

| From | Event | To | Invariant |
|---|---|---|---|
| n left | free ball graded | n-1 left | Pro never consumes (tested) |
| 0 left | `build` | summary at the free limit, no run drawn | never discover the cap after reading a ball |
| summary at limit | midnight (`dayChanges`) or foreground on a new day | new run | tested in `ServiceTests` |
| summary at limit | becomes Pro | new run (`onChange(isPro)`) | none |
| same date | westward zone change | 15 left again (product call 2) | none |

### SM3. A run (`RallyView` `@State`)

State: `balls`, `index`, `picked`, `timedOut`, `finished`,
`stoppedAtFreeLimit`, `recordedRun`, `clockRemaining`, `ballShownAt`,
`cardExpanded`.

Invariants: R1 a run is recorded once (`recordedRun`, one `endRun`); R2 a ball
is graded once (`isGraded` gates `onPick`, `select` ignores taps for 0.6 s
after a new ball); R3 the clock spends only active, uncovered time
(`clockRuns`, tested).

| From | Event | To | Invariant |
|---|---|---|---|
| deciding | pick | graded, ball consumed, replay | R2 |
| deciding | clock expires | graded as a miss | R3 |
| graded | Next, more balls | deciding, next ball or next point | R2 |
| graded | Next, no more points | summary, run recorded | R1 |
| graded | Next, allowance gone | summary at the free limit, run recorded | R1 |
| summary | Play another run | new run, all counters reset | R1 |

No invalid transition found. `playAgain` resets every counter `endRun` reads.

### SM4. Streak and today's balls (`MasteryStore`)

State: `streak`, `lastPracticeDay`, `ballsToday`, `ballsDay`, persisted in
one blob (`mastery.v1`).

Invariants: S1 a practice day is 5 balls on one calendar date; S2 the streak
counts consecutive practice dates; S3 a gap of 2 or more dates ends it, even
with no ball played since.

| From | Event | To | Invariant |
|---|---|---|---|
| count k on date D | ball on D | k+1; at 5, practice day | S1 |
| practice day D | 5th ball on D+1 | streak+1 | S2, tested across every zone's 2026 clock changes |
| practice day D | rollover on D+2 or later | streak 0 | S3 |
| practice day D, zone moves west | rollover on D+1 | streak 0 (B1) | S3 misapplied |
| count k on D, zone moves west | ball on D | count 1 (B2) | S1 broken |
| practice day D, zone moves east | anything | correct | none |

### SM5. Traps and focus (`MasteryStore.mistakes`, `focus(for:)`)

A miss with a named trap increments `misses` and resets `fixes`; a focus ball
on that trap answered right increments `fixes` up to `misses`. Open means
`misses > fixes`. Retired trap ids are kept but never open. No invalid
transition found; covered by `ServiceTests.testAMissNamesItsTrapAndAFocusFixClosesIt`.

### SM6. Onboarding (`PlayerProfile.setupComplete`, `OnboardingView.step`)

Three steps in `@State`; only the last writes level, side and
`setupComplete`. Killed mid-way, onboarding restarts at step 1 with nothing
half-saved. No invalid transition.

### SM7. Rating ask (`ReviewPromptTracker`, before Rollout S)

`completedSessions` counted every finished run with a graded ball;
`hasPrompted` made it a single ask ever, at the third run. See product call 3.
Rollout S replaced this machine (see `rollout-2026-11-24.md`).

### SM8. Legacy notifications (`LegacyReminders`)

This build schedules nothing. Launch removes the two 1.0 identifiers every
time; tested with a spy.

## Not found

Notifications: none scheduled, none to reconcile with permission. Widgets:
none. Undo and edit paths: none; the only user data is the mastery blob,
appended to and never edited. Derived totals: `rankedMistakes` and
`openMistakes` are computed on read from the tallies. Mounted-together
screens: the court and "Your game" read the same singletons; `RallyView`'s
run state is not mirrored anywhere else.

## Phase 2: skeptical review

Re-read as an independent reviewer:

- **B1 survives.** The route needs no special build or setting: a time zone
  change is something iOS does on its own when a phone lands. The test proves
  the store's own arithmetic, not a broken setup: the preconditions show the
  same state reads streak 1 under both calendars before the rollover, and the
  control shows the identical sequence in one zone gives 2. `load(_:)` is not a
  shortcut around shipping code: it stands in for the resident singleton, whose
  `Calendar.current` changes zone without a reload.
- **B2 survives**, with a narrower population (a travel day split across
  zones). Same root cause and the same fix; kept as its own row because the
  symptom and the route differ.
- Product calls 1 to 8 stay uncounted: each is either documented behaviour,
  favours the player, is handled by another rollout, or has no cited promise.
