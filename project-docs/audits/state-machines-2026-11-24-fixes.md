# State machine fixes, 2026-11-24

From `state-machines-2026-11-24.md`. Claims surviving the skeptical review: 2.
Fixed: 2. Held: 0. Skipped: 0.

| Claim | Outcome | Commit subject | Regression test |
|---|---|---|---|
| B1, a westward time zone change ends the streak | fixed | `fix: keep the streak and today's balls across a westward time zone change` | `StreakTimeZoneTests.testAStreakSurvivesAWestwardTimeZoneChange` |
| B2, a westward change mid-day restarts today's ball count | fixed (same commit, same root cause) | `fix: keep the streak and today's balls across a westward time zone change` | `StreakTimeZoneTests.testTodaysBallsSurviveAWestwardTimeZoneChange` |

Root cause: `MasteryStore` stored the practice day and the ball-count day as
`calendar.startOfDay(for:)`, an instant, and read it back in whatever zone the
device was in later. West of where it was written, that instant falls on the
day before.

Fix: `MasteryState` gains `lastPracticeDate` and `ballsDate`, a `CalendarDay`
(Gregorian year, month and day in the zone the ball was played in), and the
streak arithmetic runs on those. The instants are still written, so an older
build reading the blob behaves as before.

Upgrade: both fields are optional, so a blob saved before them decodes; until
the next ball is played each falls back to the stored instant read in the
current zone, which is exactly what earlier builds did. No stored value is
reset or dropped. `testABlobSavedBeforeTheDateFieldsKeepsItsStreak` builds a
blob without the fields, checks it decodes with its streak and count, and
carries the streak on to the next day. The existing time zone suite in
`ServiceTests` (every zone's 2026 clock changes, the Chinese leap month,
Santiago's 01:00 days) still covers same-zone behaviour.

Regression proof: the two claim tests are the repro tests verbatim, which
failed on `f17ae53` (see the audit). The full-suite run with the fix did not
start within the 60-minute limit (see `rollout-2026-11-24.md`), so the passing
half of the proof is still owed by the caller's full run.

## Held for Jack

None.

## Skipped

None.
