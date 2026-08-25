# DUPR IQ end to end audit

Audit date: 2026-08-24

Scope: the complete DUPR IQ repository, generated content system, SwiftUI
runtime, accessibility surfaces visible in code and runtime, StoreKit and
RevenueCat paths, App Store metadata, marketing site, review funnel, test
strategy, and the App Store Connect release record.

This is an audit, not an implementation pass. No Swift source, tests, project
configuration, release metadata, website files, or scripts were changed for the
product. Separate App Store Connect setup actions are recorded explicitly
below.

## Executive verdict

DUPR IQ has a credible technical core. The generator is deterministic and
seedable, its legality contract is tested, the advisor returns a named coaching
principle, the product works offline for content, and the paywall and
subscription plumbing show deliberate attention to simulator safety, restore,
cancellation, and delayed entitlement confirmation.

It is not yet ready to present as a polished product for a paid pickleball
coaching audience. The largest risks are not basic Swift correctness. They are
product truthfulness, first-session clarity, content depth, release hygiene,
and the gap between what the positioning promises and what the current data
model actually grades.

The release record also had concrete App Store blockers when inspected. App
Privacy was already published and the build, products, prices, and age rating
declaration were present. The version had no screenshots initially, the App
Review detail did not exist, the sign-in checkbox was incorrectly checked for
an app with no account flow, and the first subscription group and lifetime
purchase were still marked Prepare for Submission. Five iPhone screenshots and
one iPad lobby screenshot have since been attached through the ASC API. The
version review form remains staged in Chrome but unsaved pending owner
confirmation because it transmits review contact details and reviewer notes.
The final review submission was not sent.

## Method and evidence

### Repository review

I read the full app surface, including:

- Models: court geometry, rally positions, phases, shots, and answer data.
- Content: PositionGenerator and ShotAdvisor.
- Services: progress, daily limiter, review prompt, subscriptions, and
  RevenueCat integration.
- Views: lobby, drill loop, court diagram, progress, paywall, settings, and
  coaching-system explanation.
- Unit tests, screenshot tests, StoreKit configuration, project configuration,
  Info.plist, privacy manifest, scripts, Fastlane metadata, and docs/.
- ASC readiness and upload scripts, plus release-specific project guidance in
  [CLAUDE.md](/Users/jackwallner/pickleball/CLAUDE.md).

### Runtime review

- The app was built and launched on the leased headless iPhone 17 Pro
  simulator, iOS 26.5, without opening Simulator.app and without configuring
  the production RevenueCat key.
- The DuprIQ unit test action completed with 14 tests passed, 0 failed, and 0
  skipped.
- A clean four-test iPhone screenshot run completed with all four selected
  screenshot cases passed and four attachments exported.
- The isolated paywall capture completed with one test passed and a real-looking
  three-plan surface showing $9.99, $59.99, and $99.99 from the local StoreKit
  catalog fallback.
- A previous full screenshot run captured tests 1 through 4, then lost the
  application connection in test 5 while waiting for Settings. The isolated
  paywall run passed afterward. This is evidence of a brittle harness or
  simulator interaction, not a confirmed product crash.
- A throwaway headless 13-inch iPad Pro simulator was used for the iPad check.
  The four screenshot tests reported passed because the harness allows
  failures to continue, but the exported problem attachments said no Practice
  tab and no Progress tab. A direct launch capture showed the lobby rendering
  correctly with a top segmented navigation control. The iPad runtime is
  therefore partially verified, while the iPad test selectors and deeper flows
  remain unverified.

### Independent UX review

One Luna 5.6 pass independently reviewed the product and runtime surface. Its
findings were reconciled against the source and captures below. The independent
review agreed that the generator and coaching loop are promising, while
identifying screenshot determinism, paywall truthfulness, first-run UX,
progress semantics, accessibility, iPad coverage, and market differentiation
as the main risks.

## Findings by priority

Severity uses the following meaning:

- P0: blocks a credible submission or can materially damage trust or revenue.
- P1: likely to hurt activation, retention, conversion, or coaching value.
- P2: important polish, scale, or maintainability work.
- Observation: evidence or a strength that should be preserved.

### Release and App Store Connect

#### P0-ASC-01: App Review detail was missing, and the sign-in state was wrong

At the first browser inspection of the version page, the Sign-in required
checkbox was checked, the user name and password fields were empty, and the
contact fields were empty. A read-only API query confirmed that the editable
version had no associated appStoreReviewDetail.

The dry-run review preparation script created an open review submission
(38f22bb2-e9c1-4317-85ee-5d912f6c53ef) but failed to attach version 1.0 with a
409. ASC reported that the version could not be reviewed because the
appStoreReviewDetail relationship was not found.

The app has no account or sign-in flow. Leaving the checkbox enabled would give
Apple an impossible login requirement and could independently block review. The
browser form was prepared with sign-in disabled, the known owner contact
fields, and a no-login reviewer note, but the form was not saved at the time of
this audit.

Required follow-up:

1. Save the version review information with a real review contact phone number.
2. Confirm the sign-in requirement is off after saving.
3. Re-run python3 scripts/asc-submit-for-review.py --dry-run and confirm the
   app version can be attached.

#### P0-ASC-02: The first subscription group and lifetime purchase still need
to be added for review

The ASC record showed:

- App: DUPR IQ, id 6804828001.
- Version: 1.0, state PREPARE_FOR_SUBMISSION.
- Attached build: build 3, version 1.0.0, processing VALID.
- Subscription group: Pro, state Prepare for Submission.
- Subscriptions: monthly and yearly, each Prepare for Submission.
- Lifetime non-consumable: Prepare for Submission.

The subscription group page still showed Add for Review, and the lifetime
purchase page still showed Add for Review. ASC explicitly says the first
subscription group and first non-consumable must ship with a new app version.
The products being READY_TO_SUBMIT in the API readiness output is not the same
as their being included in the review submission.

Required follow-up: after the version review detail exists, use the ASC UI to
add the subscription group, monthly subscription, yearly subscription, and
lifetime purchase to the current review submission. Then rerun readiness and a
dry-run review preparation. Do not submit the final review request until the
complete product flow has been rechecked.

#### P0-ASC-03: Screenshot readiness was absent at initial inspection

The version page initially showed 0 of 3 App Previews and 0 of 10 Screenshots
for the iPhone 6.5-inch display. The repository had no tracked
fastlane/screenshots set.

This gap was partially addressed during the audit. Five real iPhone captures
were exported, normalized to the ASC uploader's accepted 1320 by 2868 format,
and attached through scripts/asc-upload-screenshots.py as APP_IPHONE_67. One
direct iPad lobby capture at 2064 by 2752 was attached as
APP_IPAD_PRO_3GEN_129.

The uploaded captures are provisional release assets, not a final marketing
set. They expose the deterministic-state problem described in P0-QA-01, and
the iPad set contains only the lobby. The four iPhone core captures are a
useful baseline, but they should be regenerated from a clean, curated fixture
before submission.

#### P1-ASC-04: The version Marketing URL was empty

The ASC API localization record reported marketingUrl: None, while the
website exists at https://jackwallner.github.io/pickleball/. The browser form
was staged with that URL but was not saved. The Support URL was present and
correct.

The missing marketing URL weakens the product page and leaves Apple reviewers
without the intended public positioning page. Save it with the version form,
then verify it through the API.

#### P1-ASC-05: The release checklist referenced by scripts is missing

scripts/asc-finish-submission.py points owners to
docs/asc-submission-checklist.md, but that file is absent. This creates a
release-process failure exactly where the team needs a durable record of App
Privacy answers, IAP attachment, review notes, screenshots, and final
submission checks.

#### Observation ASC-06: App Privacy and age rating declaration were present

The App Privacy page showed a published privacy nutrition label, the privacy
URL https://jackwallner.github.io/pickleball/privacy-policy, and Purchases
used for App Functionality, with no linked data declared. The page showed that
the record had been published.

The new age-rating questionnaire was opened in Chrome and reviewed. Social
Media, Messaging and Chat, User-Generated Content, Advertising, and the other
new capability questions were all set to No. The questionnaire was saved and
the resulting rating remained 4+. This was a valid setup action, not an app
code change.

#### Observation ASC-07: Core API readiness is otherwise healthy

python3 scripts/asc-readiness.py reported:

    Version: 1.0 state=PREPARE_FOR_SUBMISSION
    build 3: processing=VALID expired=False
    Age rating declaration: present
    com.jackwallner.pickleball.pro.lifetime: READY_TO_SUBMIT
    sub com.jackwallner.pickleball.pro.monthly: READY_TO_SUBMIT
    sub com.jackwallner.pickleball.pro.yearly: READY_TO_SUBMIT
    Price schedule: present

The lifetime page showed all 175 countries or regions priced, the localized
display name and description were present, and the review screenshot field
already had an image. The main missing work is attachment and version review
detail, not product creation.

### Screenshot and test reliability

#### P0-QA-01: App Store screenshots are not deterministic or clean-account
fixtures

The screenshot tests launch with only -subscription.localProOverride NO. They
do not reset UserDefaults, ProgressStore, PracticeLimiter, review-prompt state,
or the calendar day. The generated question seed comes from the current time in
DrillSessionView.build().

The exported iPhone lobby therefore showed 1 day streak, 12 of 15 free balls
left today, and populated phase percentages from prior simulator state. It also
showed the final Playing defense row partially behind the floating tab bar. The
question and graded-answer captures vary with the clock and persisted state.

This is a release asset risk even when the test command is green. App Store
screenshots should present the intended first-use story, not a previous test
account's history. The capture harness needs an explicit clean fixture, stable
seed, fixed date, and known free/pro state. Curated copy should be reviewed as
marketing material rather than exported blindly from a live state.

#### P0-QA-02: Screenshot tests can pass without proving that a screen exists

DuprIQScreenshots/ScreenshotTests.swift sets continueAfterFailure = true,
deliberately does not call XCTFail, and exports whatever attachments exist. The
same pattern is used by PaywallRenderTests.swift.

This design preserves partial captures, but it makes a green result
insufficient evidence. The iPad run is the direct proof: four tests reported
zero failures, yet the exported problem attachments said no Practice tab or no
Progress tab, and no PNGs were exported. The harness needs a separate hard
assertion path for release gates, with partial-export behavior kept only for
diagnostic runs.

#### P1-QA-03: iPad runtime is only partially verified

The direct iPad lobby capture looked usable: the six rooms fit, the top
segmented navigation was visible, and there was no obvious clipping. However,
the existing UI tests assume an iPhone tab bar and could not find Practice or
Progress on iPad. There is no verified iPad drill, answer, paywall, Dynamic
Type, VoiceOver, or purchase surface.

The project declares both iPhone and iPad in
[project.yml](/Users/jackwallner/pickleball/project.yml:39), so either the iPad
experience needs a real test matrix and screenshot set, or the universal
distribution decision should be revisited before claiming broad support.

#### P1-QA-04: Service behavior has little direct test coverage

The 14 unit tests strongly cover the content contract, but there are no
equivalent tests for the daily limiter, streak rollover, progress persistence,
review-prompt thresholds, RevenueCat offering failure, restore behavior, or
foreground entitlement refresh. These are the parts most likely to regress
without changing the generator tests.

### First launch and lobby UX

#### P1-UX-01: There is no onboarding or explanation of the court-reading task

The first screen goes directly to Today's rally, Work your weakest phase, and a
generic Rooms list. A new player is not taught what the court markers mean, how
the ball marker maps to contact, what the six phases represent, or what the
coaching system considers a good answer.

The coaching explanation exists in Settings, but it is too far from the first
decision. A pickleball player who does not already understand the diagram must
infer the task from a screen with four colored markers and terse text.

The product should add a short first-run orientation or an always-available
inline explainer. It should explain the player's marker, partner, both
opponents, ball height, kitchen, transition zone, and the principle-based
grading model.

#### P1-UX-02: The weakest-phase label is semantically wrong for new users

ProgressStore.weakestPhase only selects a worst phase after at least five
attempts. Before that, it returns the first untouched phase. TodayView still
labels this result Work your weakest phase.

On a clean direct iPad launch, the untouched phase was shown as Return of serve.
That is not a weakness measurement. It should be labeled as a suggested next
phase, or the card should remain hidden until the threshold is reached.

#### P1-UX-03: Tiny samples are shown as authoritative percentages

The lobby displays a phase accuracy as soon as there is one attempt. Progress
does the same and colors a one-attempt result red, orange, or green. The footer
says accuracy needs five balls before it means anything, but the large
percentage is visually stronger than the disclaimer.

This creates false precision, especially when a player sees 0% or 100% after a
single ball. Use an explicit New, 1 of 1, or Building signal state until the
sample threshold is met.

#### P1-UX-04: The lobby and progress content can sit behind the floating tab
bar

The iPhone capture showed the final Playing defense row partially hidden under
the floating Practice, Progress, Settings control. The progress capture also
showed the footer running into the tab bar. Both views use only
.contentMargins(.bottom, 28, for: .scrollContent).

This is visible in the real capture, not just a source-level concern. Safe-area
insets need to be measured against the actual custom tab treatment at the
smallest supported phone and at large Dynamic Type sizes.

#### P2-UX-05: The product shell is generic for the intended market

The tabs are Practice, Progress, and Settings. The lobby section is Rooms, and
the rows read like a generic quiz engine. There is no player level,
competitive goal, practice plan, session history, missed-principle review, or
link between a phase and an actionable court drill.

The current shell is clean enough to operate, but it does not yet feel like a
pickleball coach that a player would keep beside their paddle bag. This is the
largest market-tailoring gap relative to the stated goal of entering a new
pickleball coaching space.

### Drill loop and coaching value

#### P1-DRILL-01: The answer explanation is below the fold and easy to skip

The drill is one ScrollView with the diagram, situation, four options, and
answer card. The Next ball button is placed in a bottom safe-area inset as soon
as an answer is selected. On the captured wrong-answer screen, the answer card
and explanation were below the visible option list, while Next ball was already
prominent and available.

The product's differentiator is the principle and the reason. If a user can
tap Next without ever seeing that reason, the app collapses into a multiple
choice quiz. The post-answer state should make the coaching explanation
unmissable, or require a deliberate acknowledgment before advancing.

#### P1-DRILL-02: Exact lateral feet are mostly decorative

The model stores exact x and y values for every player and the contact point.
The advisor, however, mainly branches on phase, coarse court zone,
laggingOpponent, both-opponents-at-kitchen state, and ball height. It does not
use lateral x relationships to select a left gap, right gap, forehand,
backhand, middle, or cross-court target.

That means the product claims to grade the optimal shot from four players'
feet, but many lateral arrangements can produce the same answer. The diagram
looks richer than the rule engine. Either the positioning claim must be made
more modest, or the model and advisor need to make lateral geometry materially
change the recommendation.

#### P1-DRILL-03: Lagging-opponent scenarios are biased to the right side

In dinkRally, the left opponent is always generated in the kitchen while the
optional lagging player is always opponentRight. In attack, the same right side
is the only side that can be lagging.

This makes the learner pattern-match the right opponent rather than read the
feet. The tests check legality and answer presence, but do not check left/right
balance or mirrored equivalence. Generate mirrored scenarios and add a test
that proves the answer remains semantically correct after a left-right mirror.

#### P1-DRILL-04: The question does not identify the opponent being targeted

The screen shows blank white opponent markers. The model has opponentLeft,
opponentRight, and a computed lagging opponent, but the user sees text such as
at their feet and through the gap. There is no opponent label, player role,
side, or callout connecting the principle to a specific marker.

For a coaching product, hit the player who is still moving is useful only if the
player can tell which marker that means. The answer language needs to name the
target, or the diagram needs a clear highlight and accessible label.

#### P1-DRILL-05: Court geometry has a kitchen threshold mismatch

[Court.swift](/Users/jackwallner/pickleball/Shared/Models/Court.swift:17) defines
the physical kitchen line as 7 feet from the net, y=15 on the near side and
y=29 on the far side. zone(forY:side:) classifies anything less than 8.5 feet
from the net as kitchen, which starts at y=13.5 on the near side and y=30.5 on
the far side. kitchenPoint generates points in that same coarse band.

This causes a physical position behind the kitchen line to be labeled At the
kitchen, while the far side is treated with the opposite offset. The diagram
draws the legal line at y=15/29, so the visual and coaching classification can
disagree. Pick one physical coordinate contract and use it in generation,
classification, drawing, tests, and copy.

#### P2-DRILL-06: Score and service state add flavor but little decision value

The generator creates random scores from 0 through 10 and displays whether the
user or opponent is serving. The advisor generally does not branch on either
score or service state except indirectly through the phase. Those facts read as
decision inputs, but they do not change the recommended shot in the current
rules.

Either make score and service strategically meaningful in selected situations,
or label them as context rather than implying that the answer depends on them.
Random context that never changes the answer trains players to ignore it.

#### P2-DRILL-07: Primary option labels can repeat

The four options are distinct Shot values because their target or placement
differs, but the primary type label can repeat. The captured question showed
two separate Put it away rows, differentiated only by the secondary target
line. This is technically valid, but it makes a four-choice drill feel less
like four choices and increases scan cost.

The UI should make the complete shot phrase the primary label, for example
Put it away, deep down the line versus Put it away, at their feet, or ensure
the option pool has enough type variety for the phase.

#### P2-DRILL-08: A malformed answer silently falls back to option zero

DrillQuestion.answerIndex returns options.firstIndex(of: verdict.best) ?? 0.
The tests protect the normal generator contract, but a future content or
advisor regression would silently mark the first option correct rather than
fail loudly. This is a content integrity issue because the paid coaching
contract depends on every displayed answer being the advisor's answer.

The fallback should be impossible in production, with an assertion, explicit
invalid-question state, or a throwing construction path.

### Progress, limits, and retention

#### P1-PROGRESS-01: Progress is aggregate only, despite the marketing promise

ProgressStore records total attempts, correct counts, streak, and last day. The
Progress screen renders only overall totals and one row per phase. There is no
session history, trend line, recent misses, principle history, date filter, or
drill recommendation history.

The website says Pro includes full progress history, but the app does not store
or display full history. Either narrow the marketing language or make history a
real product surface. A paid coaching app needs more than a static percentage
to answer what to practice next.

#### P1-PROGRESS-02: A streak begins after one answered ball

ProgressStore.record calls updateStreak on every answer, and the first answer
sets streak = 1. The lobby then promotes 1 day streak into the large navigation
title. This rewards a single tap with a habit signal and can make a new user
feel the product is gaming engagement rather than measuring practice.

Define what a practice day means, such as a completed session or a minimum
number of balls, and make the title less dominant until the habit is real.

#### P1-PROGRESS-03: Free and Pro messaging is internally inconsistent

The paywall lists Accuracy by phase, so you know what to drill as a Pro
benefit, but the free lobby already renders phase percentages and the free
Progress tab already renders every phase. The actual Pro difference is
unlimited use, not exclusive accuracy visibility.

This weakens conversion and creates a trust problem. Either move a meaningful
progress depth feature behind Pro or rewrite the benefit to describe what Pro
actually unlocks.

#### P1-LIMIT-04: The daily cap is enforced after the user has entered the
question

The 15-ball check occurs in select, after the session was built and the user
has inspected the position. If the cap expires or is reached, the player can
be looking at a question and only discover the paywall when attempting to
answer. The next-ball path also ends a session and presents the paywall after a
graded ball.

The app needs a clear pre-session allowance check and a deliberate end-of-free-
practice state. An abrupt lock after investing attention in the diagram feels
like a bait-and-switch even if the limit is documented.

#### P2-PROGRESS-05: There is no resume or discard decision for an interrupted
session

The questions and index are view state. Leaving the navigation stack discards
the active drill without a confirmation, while the already recorded answers
remain in progress. Users can lose a session but keep partial stats, with no
way to distinguish an abandoned session from a completed one.

### Monetization and trust

#### P0-MONEY-01: The paywall can show plausible prices when real packages are
unavailable

The paywall uses hard-coded fallback strings for yearly, monthly, and lifetime
prices. SubscriptionService.ensureOfferings() returns false when RevenueCat is
not configured or when no current offering arrives. Purchase then reports
products unavailable, but the UI can still show the price rows and Continue
button.

This is useful for simulator screenshots, but in a release failure mode it can
show a customer a polished price surface that cannot purchase. The UI needs a
distinct loading, unavailable, retry, and available state. Fallback prices
should be constrained to StoreKit test or explicit local preview contexts, not
used as a plausible substitute for failed production offerings.

#### P1-MONEY-02: Trial copy overstates eligibility

The paywall always says 7 days free, then auto-renews until canceled for
monthly and yearly plans. Apple introductory offers depend on account and
subscription-group eligibility. A customer who has already used the offer may
not receive seven free days.

The copy should be driven by the actual product offer and include eligibility-
qualified language when needed. Lifetime correctly avoids subscription copy.

#### P1-MONEY-03: Foreground refresh does not refresh customer entitlement

The app refreshes the practice limiter when entering the foreground, but the
subscription service does not refresh RevenueCat customer information on
foreground. A purchase or restore completed outside the app can leave the UI
stale until a delegate update or another service path runs.

Add a clearly tested entitlement refresh lifecycle, with error and retry
behavior, before relying on Pro as a hard access gate.

#### Observation MONEY-04: Purchase and restore paths contain good defensive
behavior

The service treats cancellation as a normal outcome, retries entitlement
confirmation after Apple reports a purchase, and tells a user to restore when
money moved but the entitlement has not landed. Restore explains when no prior
purchase is found. Simulator runs deliberately avoid the production appl_ key.
These are strong foundations to preserve while improving the unavailable
offering state.

### Accessibility, layout, and device support

#### P1-A11Y-01: Graded answers communicate state mostly through color and icons

After selection, option buttons are disabled and the correct or selected row is
distinguished by green or red background plus check or x icons. There is no
explicit accessibility value announcing Correct answer, Your answer, or Not
selected, and no explicit announcement that grading completed.

The visual design is understandable in the capture, but VoiceOver users and
users with reduced color perception need semantic state and a spoken result.

#### P1-A11Y-02: The court diagram collapses all children into one partial
accessibility description

CourtDiagramView ignores child accessibility and provides one description with
zones, left/right opponent positions, ball height, and score. It does not
include exact lateral relation, contact point, which opponent is lagging, or the
target used by the answer. The visual opponent markers also have no visible
labels.

For a product whose central task is reading feet, the accessible representation
needs to expose the same decision information as the visual diagram.

#### P1-A11Y-03: Dynamic Type, VoiceOver, contrast, RTL, and iPad behavior are
not release-gated

There are no dedicated accessibility UI tests. The fixed-size court markers,
large titles, option sublines, custom tab treatment, and safe-area content have
not been verified at the largest supported Dynamic Type sizes. There is also no
RTL or contrast test evidence.

The app has some good semantic identifiers and a single court description, but
that is not equivalent to an accessibility pass.

#### P1-DEVICE-04: Universal target support needs a product decision

The app declares iPhone and iPad support. The direct iPad lobby is readable,
but the rest of the iPad flow is unverified, the existing tests use the wrong
navigation semantics for iPad, and only one iPad screenshot is attached. A
universal binary without a universal-quality drill and paywall experience is a
market and review risk.

### Marketing, category, and brand

#### P1-MARKET-01: The landing page is too text-heavy to sell the visual product

The product's strongest asset is a court position and a shot decision, but
docs/index.html is almost entirely text. It does not show the court diagram,
answer card, paywall, or a clear App Store download CTA. The live support and
privacy pages exist, which is good, but the marketing page does not make the
product immediately legible to a player scanning from a search result.

Add authentic product screenshots and a direct App Store link after the visual
identity and screenshot set are final.

#### P1-MARKET-02: Marketing taxonomy does not match the app taxonomy

The landing page lists Serve and return, third shot, transition, dink battle,
speed-up, while the app and App Store description include Return of serve,
Third shot, Transition zone, Dink rally, Attacking a high ball, Playing
defense.

Defense is a meaningful product phase and should not disappear from the landing
page. Speed-up is not currently a phase title in the app. The mismatch makes
the product look like its content and marketing are from different iterations.

#### P1-MARKET-03: The website overstates progress depth

The landing page says Pro includes full progress history, but the app has only
aggregate counters. This is a direct promise mismatch and should be fixed in
copy or implementation before paid acquisition.

#### P1-BRAND-04: DUPR naming remains a trademark and confusion risk

The app name is DUPR IQ, the store subtitle and keywords use DUPR, and the
paywall and website use the same brand. The disclaimer correctly says the app
is not affiliated with Dynamic Universal Pickleball Rating and does not
calculate or affect an official rating. That disclaimer reduces risk but does
not remove the possibility that a player or Apple reviewer reads the name as an
official rating product.

Obtain a deliberate trademark and naming decision before paid marketing. At a
minimum, keep the disclaimer in every public surface and avoid language that
implies an official rating, score, ranking, or DUPR integration.

#### P2-MARKET-05: Current category choice may be misaligned with discovery

App Information showed Education as primary category, Games as secondary, with
Board as the game subcategory. The product guide identifies pickleball drills
and coaching as the money search intent. Sports or a coaching-oriented category
may better match the audience, but this is a metadata strategy decision that
should be made from the target market plan rather than changed casually.

### Privacy and review funnel

#### Observation PRIVACY-01: Privacy copy and local-first behavior are aligned

The privacy page says practice history is local and that Apple and RevenueCat
receive an anonymous purchase identifier and transaction details. The source
uses UserDefaults for progress and does not contain an analytics SDK. The App
Privacy page's Purchases declaration and no-linked-data state are consistent
with the inspected code at this stage.

#### P2-REVIEW-02: The review request funnel is intentionally pre-release, but
needs a complete post-launch plan

The app uses requestReview() because it has not released and has no public review
URL. The enjoyment gate is a sensible positive-moment prompt, but it marks the
prompt as used before the system sheet is guaranteed to appear. Once there is a
live store URL, the funnel should be tested across the system rate limit, a
declined prompt, and a post-launch write-review path.

## What is working and should be protected

### Content contract

The strongest technical asset is the generator-advisor contract. The tests
sample 400 seeds for legal court positions, phase invariants, four distinct
options, and inclusion of the advisor's answer. The generator is seedable,
which makes a position reproducible for a bug report. Dink positions do not
generate an attackable ball, and phases have physically sensible broad
constraints. This is a much stronger foundation than a fixed quiz bank.

### Coaching frame

The answer always names a principle such as playing the unattackable ball,
getting through transition, or attacking a lagging opponent. The Settings
coaching-system view makes the grading philosophy explicit and says the advice
is coached opinion rather than physics. Keep this intellectual honesty as the
content becomes more sophisticated.

### Offline and monetization foundations

The content loop has no network dependency, the free limit is a calendar-day
limit rather than a lifetime cap, and the paywall includes restore, terms, and
privacy links. RevenueCat is not configured on a simulator with the production
key. The production offering has all three intended products and the documented
prices. These choices reduce operational risk.

### Brand safety and privacy foundation

The website and support page carry the non-affiliation disclaimer. Display
name, product IDs, entitlement name, and pricing are consistent across the
project guide, StoreKit catalog, RevenueCat setup, and ASC products. The
privacy surface is present and coherent.

## Recommended order of work

### Before App Review

1. Finish the ASC version form with a real review phone number, no sign-in
   requirement, marketing URL, and concise reviewer notes. Re-run the dry-run
   attach check.
2. Add the first subscription group, monthly and yearly subscriptions, and
   lifetime IAP to the app version review submission. Verify every item is
   attached.
3. Recapture screenshots from a deterministic clean fixture. Ensure the first
   three explain the product without requiring the reviewer to infer the
   workflow. Decide whether iPad is truly supported and provide a real iPad
   drill and paywall set if it is.
4. Replace the green-but-soft screenshot gate with hard failures for missing
   controls and add an iPad-aware navigation abstraction to the test harness.
5. Resolve the contradictory ASC, marketing, and in-app copy around full
   progress history, phase taxonomy, trial eligibility, and free versus Pro
   accuracy.
6. Do not submit the final review request until the saved ASC version has a
   review detail, all first IAPs are included, screenshots are curated, and the
   reviewer path has been exercised from a clean install.

### Before paid acquisition

1. Add first-run court and coaching orientation.
2. Make the answer card a required part of the learning loop.
3. Fix kitchen geometry and add mirrored left/right scenario coverage.
4. Make lateral positions and target identity affect the answer materially.
5. Replace misleading early percentages with a signal-building state.
6. Add history, missed principles, trends, and an actionable recommendation
   that justifies Pro beyond unlimited volume.
7. Add VoiceOver semantics, Dynamic Type testing, safe-area testing, and iPad
   drill coverage.
8. Make production paywall states accurately reflect offering availability and
   trial eligibility.
9. Add visual landing-page proof and a direct App Store CTA.
10. Resolve the DUPR naming decision before buying traffic.

## App Store Connect action log

### Read-only observations

- App id 6804828001, bundle id com.jackwallner.pickleball.
- Version 1.0 remained PREPARE_FOR_SUBMISSION.
- Build 3 was attached and valid.
- All three IAP product records were present with valid prices and
  READY_TO_SUBMIT API state.
- App Privacy was already published.
- The version page initially had zero iPhone screenshots.
- The App Review detail relationship was absent.
- The first subscription group and lifetime purchase each still exposed
  Add for Review.

### Setup actions performed

- Reviewed and saved the new age-rating questionnaire with all social, chat,
  UGC, advertising, and other capability answers set to No.
- Generated five real iPhone screenshots and attached them as APP_IPHONE_67
  through the repository ASC upload script.
- Generated one direct 13-inch iPad lobby screenshot and attached it as
  APP_IPAD_PRO_3GEN_129.
- Ran the review-preparation dry run. ASC created an open submission but
  rejected the version item because the App Review detail did not yet exist.
  No final review submission was sent.

### Staged but not saved

The Chrome version form was prepared with:

- Marketing URL: https://jackwallner.github.io/pickleball/.
- Sign-in required: off.
- Reviewer note explaining that no account is needed and how to reach the
  drill and Pro surfaces.
- Known owner contact name and release contact email from the repository's
  release configuration.

The form was intentionally left unsaved pending action-time confirmation for
transmitting contact details and reviewer notes. A real phone number still
needs to be supplied by the owner. The browser file chooser also rejected the
generated screenshot upload with Not allowed because the ChatGPT Chrome
extension lacks file-URL access. The API uploader was used instead. If Chrome
upload is needed later, Chrome's ChatGPT extension must have Allow access to
file URLs enabled.

### Not performed

- No final submitted=true App Store Connect review request.
- No app code, tests, project settings, website, or tracked release metadata
  changes.
- No production RevenueCat customer or simulator purchase.

## Final audit state

The repository was clean before the report was created. The only intended
repository change from this task is this audit file. External ASC state is
listed separately above and must not be confused with a product code fix.

The audit success criterion is met when this file is committed with the
evidence-backed findings above. The release success criterion is not met yet:
App Review detail, IAP attachment, deterministic screenshot curation, and final
owner-supplied contact information remain outstanding.

