---
paths:
  - "Shared/Content/RallyBuilder.swift"
  - "Shared/Content/EndlessPractice.swift"
  - "Shared/Services/AppSettings.swift"
  - "DuprIQ/Views/DrillSessionView.swift"
  - "DuprIQ/Views/Drills/*.swift"
  - "DuprIQ/Views/Components/QuestionUI.swift"
  - "DuprIQTests/RallyBuilderTests.swift"
---

# DUPR IQ: rallies and session runners

Moved verbatim from AGENTS.md. Loads when a matching file is read; update it here.

### Points, not balls

`RallyBuilder` builds POINTS. A correct decision advances the same rally to your
next shot; a wrong one loses the point and skips the rest of it, the way a real
one ends. `RallyBuilderTests` pins the part that would otherwise train an
impossible sequence: the serving team never returns serve and the returning team
never hits the third shot. Metering is unchanged — every graded ball still costs
one from the daily allowance, and a session is still truncated to the allowance
rather than promising balls it cannot grade.

`AppSettings.ShotClock` adds pressure after the player understands the court read.
Generated practice defaults to untimed because a beginner first has to learn the
ball, feet, rings, and labels. Settings exposes an off-by-default Decision Timer;
enabling it starts at a nine-second learning pace, with game and fast options after
that. When enabled, a ball the player does not decide about is graded as a miss.

**Every mode that plays a generated ball draws the same court.** The pivot to the first-person court (see `court-3d.md`)
changed `DrillSessionView` and `QuickSessionView` and missed `PracticeRunView`,
so Timed Challenge and Fix My Mistakes, both Pro-locked, went on serving the
overhead diagram above a list of sentences that the pivot had replaced
everywhere else. The fix was one call site: `QuestionPager` already renders
`CourtPOVView` when it is handed `shots`, and that runner was not handing them
over. `CourtPOVView.Chrome` is what makes the same view work in both places: a
full-bleed drill reserves the HUD band and the verdict card's strip and draws
your paddle, an embedded 340 point card reserves almost nothing, shrinks the
captions, and culls the paddle (in a card it is a dark notch in the corner that
reads as a clipping artefact). `EndlessPractice.prompt` lost its ball height and
contact side at the same time: correct copy above an overhead diagram, a
giveaway printed over a render whose whole job is to make you read them.
