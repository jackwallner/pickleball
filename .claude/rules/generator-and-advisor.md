---
paths:
  - "Shared/Content/PositionGenerator.swift"
  - "Shared/Content/ShotAdvisor.swift"
  - "Shared/Content/EndlessPractice.swift"
  - "Shared/Models/RallyPosition.swift"
  - "Shared/Models/Shot.swift"
  - "Shared/Models/CourtGeometry.swift"
  - "DuprIQ/Views/Components/QuestionUI.swift"
  - "DuprIQTests/PositionGeneratorTests.swift"
  - "DuprIQTests/ShotAdvisorTests.swift"
  - "DuprIQTests/ContentTests.swift"
  - "DuprIQTests/ServiceTests.swift"
---

# DUPR IQ: the generator, the advisor and their contracts

Moved verbatim from CLAUDE.md. Loads when a matching file is read; update it here.

**`EndlessPractice` is the graft seam.** It turns a `DrillQuestion` into the
same `QuickItem` the authored drills emit, so the session runners never have to
know whether a question was written by hand or generated a second ago. The one
thing that could not be adapted away is the court: `QuickItem` carries an
optional `position`, and `QuestionPager` renders `CourtDiagramView` when it
finds one and a row of `Given` chips when it does not. Four sets of feet ARE
the question; flattening them into prose would delete the app.

`PositionGeneratorTests` and `ShotAdvisorTests` are the content contract.
If a generated position is off-court, the answer is missing from the
options, or a dink rally ships an attackable ball, the paid tier is
broken. Do not weaken those tests to land a generator change.
`ServiceTests` is the equivalent contract for the daily cap, the streak rule,
the accuracy sample threshold, the practice history and the review gate: none
of those regressions show up in a generator test.
`CourtCameraTests`, `ShotTargetingTests`, `AimLabelLayoutTests` and
`RallyBuilderTests` are the contract for the first-person pivot: what must be in
frame AND where in the frame, where a shot lands, that four captions stay apart,
below their rings and distinguishable from each other, and that a point is a
sequence someone could actually play. Every one of them exists
because of a failure a screenshot caught and no other test would have.
`ContentTests` is the contract for everything the port brought in: that every
authored question is answerable, that the Worked Reads room cannot disagree
with the advisor, that generated balls roll up to one tracking row per phase,
and that no leftover word from the previous domains survives in the copy. It
matches on WORD BOUNDARIES, because the first version used `contains` and
failed on "tiebreaker".

**A contact is a reach from a stance.** `you` and `contact` used to be
independent draws, which routinely put the ball eight feet to the side of the
feet supposed to be hitting it. A plan-view diagram drew that as two dots near
each other; in first person it is a ball fifty degrees off your nose that no
human could reach, and it was the one generator bug the overhead view was
hiding. `PositionGenerator.contactPoint` derives the contact from `you` as a
reach, signed forward offset per phase (in front at the kitchen, late and low on
defense), and `partnerPoint` puts your partner across the center line from you
instead of, sometimes, inside your own head.

**Lateral position is load-bearing.** The advisor branches on where the contact
sits relative to the center line (no long diagonal exists from the middle) and
on how far apart the two opponents are standing (an open seam beats either
body). Every generated position is mirrored with probability one half, and
`testTheAnswerIsUnchangedUnderALeftRightMirror` pins the property that makes
this a decision rather than a side: reflect the court and the shot is
identical, aimed at the marker now in the mirrored place. Any new rule has to
keep that symmetry, and any verdict that names an opponent has to carry
`targetOpponent` so the diagram can highlight the marker it means.

**One kitchen contract.** `CourtGeometry.kitchenDepth` (7 ft) is the line the
rulebook and both renderers draw. `CourtGeometry.kitchenReadyDepth` (8.5 ft) is
how far back a player can stand and still count as "at the line", because nobody
waits inside the non-volley zone. Generation, classification, the 3D scene, the
overhead and the tests all use those two constants; do not introduce a third
threshold.
