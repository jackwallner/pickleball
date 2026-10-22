---
paths:
  - "Shared/Content/RallyBuilder.swift"
  - "Shared/Models/ShotFlight.swift"
  - "Shared/Services/AppSettings.swift"
  - "DuprIQ/Views/RallyView.swift"
  - "DuprIQ/Views/Court3D/CourtPOVView.swift"
  - "DuprIQTests/RallyBuilderTests.swift"
---

# Third Shot: rallies, focus points and the replay

### Points, not balls

`RallyBuilder` builds POINTS. A correct decision advances the same rally to your
next shot; a wrong one loses the point and skips the rest of it. `RallyBuilderTests`
pins the part that would otherwise train an impossible sequence: the serving team
never returns serve and the returning team never hits the third shot. Every graded
ball costs one from the daily allowance, and a run is truncated to the allowance
rather than promising balls it cannot grade.

### Focus points (the adaptive part)

Every `RallyBuilder.focusEvery` (3rd) point is a single focus ball. Its target
comes from `MasteryStore.focus(for:)`: open traps first (a `MistakeTally` with more
misses than fixes since the last miss), then the weakest measured phase, then the
player's level's `starterPhases`. A trap-targeted focus ball is rejection-sampled
until the named trap is one of its four options. Answering one right counts as a
fix; a fresh miss resets fixes to zero. The HUD labels it `FOCUS · <trap>`.

### Side orientation

`PlayerProfile.half` mirrors positions so you stand on the half you chose. It is
safe only because the advisor is mirror-symmetric
(`testTheAnswerIsUnchangedUnderALeftRightMirror`); the verdict is re-derived from
the mirrored position, never assumed.

### The replay

After every graded ball, `CourtPOVView` flies `ShotFlight` paths from the contact:
your shot in red first (a drive at a below-net ball dies in the tape), then the
right one in green, each leaving a dotted trail. It replays when `RallyView` bumps
`replayToken` (on grading and on the Replay button). The SceneKit side uses plain
`SCNAction.move` sequences, never `customAction`: a closure created on the main
actor and run on SceneKit's render thread trips Swift 6's isolation check.
`ProductContractTests` pins that every right answer's path clears the net.

### The decision timer

`AppSettings.ShotClock` is off by default; a beginner first has to learn the ball,
feet and rings. When on, an undecided ball is graded as a miss. The clock pauses
while "Your game" is open over the court.

### The verdict card

Closed, the card is the height of the option band it replaced, which leaves
the explanation a few lines behind a fade. The grabber, the chevron
(`expand-why`), a tap on the text or a pull up opens it to fit its text, capped
at 70% of the screen; Replay, a new ball, returning from the background and
closing "Your game" all close it, because an open card hides the replay.

### Input guards

- Next sits where the option band was. `startClock()` stamps `ballShownAt` on
  every new ball and `select` ignores taps for 0.6 s after it, so a quick
  second tap on Next cannot grade a ball nobody has seen. XCUITest's "fast"
  tap pair lands about 0.5 s apart, so a 0.4 s guard does not survive it.
- Changing the shot clock in Settings mid-ball applies at once: Off stops the
  running clock instead of letting it expire unseen.
- The court and "Your game" cap Dynamic Type at XXXL (`.dynamicTypeSize`): the
  HUD, band and card are sized against the 3D view, and past XXXL they wrapped
  over the players and broke words. Onboarding is uncapped and scrolls
  (`ViewThatFits`) with Continue pinned.
- `CourtPOVView` hides its overlays until SceneKit reports a first frame
  (`FirstFrameSignal`, 1 s fallback), so a cold launch never shows labels over
  an empty field.

