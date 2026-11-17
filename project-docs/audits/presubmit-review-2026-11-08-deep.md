# Pre-submit deep review, 2026-11-08

Branch `review/2026-11-08-pickleball-deep`, cut from `origin/main` at `4d0da99` (1.1.0, build 29).

Scope: every user-reachable path on `origin/main` (purchase, restore, paywall, onboarding, persistence and migration from 1.0.x keys, notifications, Duo and iPad layout code, localization), plus the app-source diff from the last 1.0.1 commit in `project.yml` history (`8df5360`) to HEAD. No simulator or local xcodebuild was used; unit tests ran on GitHub's Macs through `gh-sim`.

Note: `AppStoreLinks.isListingLive` is still `false` and the ASC notes say 1.0 was rejected under 4.3(a), so 1.0.1 may never have reached the store. The base commit above is the last version before 1.1.0 either way.

## Findings

| Severity | Location | What happens | Status |
|---|---|---|---|
| P0 | `DuprIQ/Views/RallyView.swift:111` | The court rolled the free allowance over from `NSCalendarDayChanged` through a raw `NotificationCenter` publisher. iOS gives no thread guarantee for that notification (it is also posted on wake when the day changed during sleep), and the handler writes `@MainActor` state (`PracticeLimiter.usedToday`, the run's `@State`). Under Swift 6 a main-actor closure run off the main thread traps on the isolation check; at best it publishes UI changes from a background thread. | Fixed: `PracticeLimiter.dayChanges()` receives on the main queue. Test `testADayChangePostedOffTheMainThreadIsDeliveredOnIt` posts from a background queue and asserts main-thread delivery. |
| P1 | `DuprIQ/Views/RallyView.swift:401` | With the decision timer on, returning from the background timed the ball out on arrival: the overdue tick fires while the scene is still inactive, before the `.active` handler resets `clockLastTick`, so it spent the whole time away. The ball was graded as a lost point and cost a free ball. | Fixed: the clock only spends time while the scene is `.active` (`RallyView.clockRuns`). Test `testTheShotClockOnlyRunsWhileTheSceneIsActive`. |
| P2 | `DuprIQ/Views/RallyView.swift:449` | `build()` runs on first appear, before RevenueCat's customer info lands, so a Pro user who used free balls earlier the same day can flash the "today's 15 free balls" summary. `onChange(of: isPro)` starts a run as soon as the entitlement arrives. | Not fixed: self-heals within the customer-info fetch; no lockout. |
| P2 | `DuprIQ/Views/PaywallView.swift:204` | Restore stays tappable while a purchase is in flight (Continue is disabled, Restore is not). Both share `isWorking`, so the spinner can clear early. | Not fixed: cosmetic, no wrong entitlement state. |
| P2 | `Shared/Content/PositionGenerator.swift:24` | `DrillQuestion.init` calls `preconditionFailure` (traps in Release) if a generated option set lacks the advisor's answer, including after `RallyBuilder.oriented` mirrors a position. | Not fixed: by design, pinned by `PositionGeneratorTests`, `ShotAdvisorTests` (mirror symmetry) and `RallyBuilderTests`. |
| P2 | `DuprIQ/Info.plist:34` | iPad allows landscape while the court, HUD and verdict card are tuned for portrait. | Not fixed: not verifiable without a simulator in this pass; layout code caps sizes in points and uses `readableContentWidth`. |

## Checked and clean

- Purchase: offering and package lookups are nil-safe (`package(for:)`, `ensureOfferings`), a cancel is an outcome not an error, a paid-but-unconfirmed entitlement shows a Restore hint, prices are real or absent in Release, trial copy follows the product's intro offer and eligibility.
- Restore: paywall and Settings both report "No previous purchase found" instead of doing nothing; Pro unlocks via `apply(_:)` and the delegate.
- Gating: `isPro` is only `entitlements["pro"].isActive` in Release (the local override is DEBUG only); the daily cap is checked before a run, on every tap and on expiry; buying from the free-limit summary starts a run.
- Paywall: "Not now" always dismisses; Terms of Use and Privacy Policy links present; no hard-coded prices in Release copy.
- Onboarding: `player.setupComplete` persists and is shared with 1.0.x, so upgraders skip it and new installs see it once.
- Persistence: `MasteryState` is new (no older blob to fail decoding) and a decode failure falls back to an empty state; limiter, settings and profile keys read with defaults, and unknown 1.0.x shot-clock values fall back to Off.
- Notifications: none scheduled in 1.1; `LegacyReminders` cancels both 1.0.x identifiers at launch.
- No widgets, app intents or localizations ship; no debug UI, Android or other-platform links, or health claims are reachable in Release.
