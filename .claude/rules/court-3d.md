---
paths:
  - "DuprIQ/Views/Court3D/*.swift"
  - "DuprIQ/Views/CourtDiagramView.swift"
  - "DuprIQ/Utilities/Theme.swift"
  - "Shared/Models/CourtGeometry.swift"
  - "Shared/Models/ShotTargeting.swift"
  - "DuprIQTests/CourtCameraTests.swift"
  - "DuprIQTests/ShotTargetingTests.swift"
  - "DuprIQTests/AimLabelLayoutTests.swift"
---

# DUPR IQ: the first-person court

Moved verbatim from AGENTS.md. Loads when a matching file is read; update it here.

### The first-person court

**The decision is made in 3D; the overhead is the whiteboard afterwards.** The
old loop drew a plan-view diagram, printed the two decisive facts underneath it
in words ("Below net height, hit from the right side"), and asked the player to
pick one of four sentences. That is a flashcard: reading ball height off a
caption is not the skill the app claims to train. Now `CourtPOVView` puts you on
the court, the ball hangs at an actual height beside a net whose tape is at a
known one, and the four options are RINGS on the paint where the shot would
land. `CourtDiagramView` survives inside `VerdictCard`, behind a disclosure,
which is exactly the role it should have had: the geometry a coach draws for you
after the point, not the thing you play from.

Grading did not change. A tap still resolves to an index into
`DrillQuestion.options`, so `ShotAdvisor`, `PositionGenerator` and every test
that pins them were untouched by the pivot.

**SceneKit draws the world; SwiftUI names it.** There is no text in the scene.
Player initials and the four captions are SwiftUI, positioned by projecting
court points through `CourtCamera`, so they stay crisp, honour Dynamic Type and
reach VoiceOver. `CourtCamera` owns the projection itself rather than calling
`SCNSceneRenderer.projectPoint`, and it configures the `SCNCamera` from the same
numbers: if the captions sit on the rings in a screenshot, the two agree.

**Everything in the scene is procedural.** Boxes, capsules, spheres and tori,
sized in feet from `CourtGeometry`. No models, no textures, no growth in binary
size, and no way for the rendered court to drift from the rulebook the advisor
reasons about.

**A net is a mesh, not a panel, and the mesh has to be a haze.** This cost three
rebuilds. Drawn as a semi-transparent panel it rendered as a solid black wall
across the middle of the frame and hid the opponents, and each attempted fix
(alpha, blend mode, depth writes, rendering order) looked like it should have
worked. Rebuilt as thin boxes with holes between them it still read as a
chain-link fence across the opponents' legs: cords thin enough to be cords
render near black under a physically-based material whatever colour they are
given, and forty of them at that distance close up. They are `.constant` lit,
grey-green, 42% opaque, `writesToDepthBuffer = false`, and spaced 1.5 ft by
0.7 ft. The detour also produced a wrong camera: reasoning that a 34 inch net
hides the far kitchen from anyone at their own baseline, the eye was raised to
twelve feet to see over it, which squeezed the opponents into a thirteenth of
the screen. Do not raise the camera. You look THROUGH a net.

**The ball is measured against a bar, not against the net.** The app's whole
claim is that "can I attack this" is something you SEE, and for one build it
was not: the net is twenty-five feet away and the ball is at your shoulder, so
comparing their heights across that much perspective is guesswork and players
were back to reading the caption. `CourtScene.ball` draws a white bar at exactly
net height on the ball's own drop line, with the pole carried up through it when
the ball is lower. Ball above the bar is a ball you can hit down on, and nothing
writes that down. Two earlier shapes were wrong and both are instructive: a
torus of net-tape radius projects as a four-hundred-pixel ellipse lying across
the near court, and a smaller disc still reads as a puck on the paint, because a
disc seen from above is a disc. Only a bar reads as a height.

**The camera is framed on the four rings this question draws.** It used to be
framed on a synthetic region covering every place any option could ever land,
which spanned most of the far court on every ball, so the fit ran into its
widest allowed angle every time and pinned both opponents and all four rings
into a band across the top fifth of the screen. `CourtCamera.viewing` takes the
aim points; `CourtCamera.viewing(_ question:)` computes them. It frames the
whole RING, not the point a shot lands on, because a ring is nearly two feet
across and the outermost option was being sliced off by the edge of the screen.

**Composition is a contract, not taste.** `CourtCameraTests` now asserts that
the opponents are not jammed against the top or bottom of the frame and that
every ring leaves room under it for its caption. Containment tests all passed
while the screen was unreadable; only a screenshot caught it, which is exactly
the kind of failure this file exists to stop recurring.

**The eye is a step back and a shade low.** 8.5 ft behind your stance at 5.2 ft,
not 1.6 ft at 5.9. From a head on a body, a ball on your shoetops sits forty
degrees below the horizon while the opponents sit on it, and the frame has to
stretch across both with a third of the screen of empty near court in between.
`CourtScene.stanceRing` draws a quiet ring where you are standing so the read
the old close eye protected, how close YOU are to the kitchen, is a thing you
can see. Quiet is the operative word: the first version had a bright ring and a
vertical stake eight feet from the lens and became a fifth glowing target on our
own side of the net.

**The captions go BELOW their rings.** Lifted above them, on a portrait phone,
all four pills landed on the far court and covered both opponents' bodies and
most of the rings they named: the render was hiding the four sets of feet the
question is about. The near court below is empty by construction.
`CourtPOVView.verdictBandHeight` reserves the strip the verdict card will cover
so the captions are laid out clear of it and nothing reflows when a ball is
graded. That reserve is a cap in POINTS, not a fraction: 40% of a 13 inch iPad
is 546 points held for a card that is never taller than 330.

**A caption says the shot shape, unless two options share one.** The place is
the ring, and printing "cross-court kitchen" on a pill sitting on the
cross-court kitchen hands back the answer. But the third shot routinely offers a
drive at their feet AND a drive down the line, which captioned by shape alone is
two identical pills and a question nobody can answer. `ShotAiming.captions`
adds the place only where it is the thing telling two options apart, and
`ShotTargetingTests` pins that no two options ever caption identically.

**The camera is fitted, not fixed.** One field of view cannot serve both ends of
the court: from your baseline everything is distant and a narrow angle is right,
while from the kitchen line an opponent at the far sideline is forty degrees off
your nose. `CourtCamera.viewing` centres the head on what has to be visible and
widens the angle until it fits, then walks the eye backwards only if widening
runs out. `CourtCameraTests` asserts on every phase that the ball, the net-height
bar beside it, both opponents and all four rings are in frame and not jammed
against an edge, that depth runs up the screen and that left is left. Those are invisible failures otherwise: everything
computes, the scene renders, and the one object the question is about is simply
not there.

**Optic yellow belongs to the ball and the aim rings.** Nothing else may use it.
Your partner was painted in it and, standing a few feet from the eye, became the
largest and brightest object on screen.

**Where a shot lands is a pure function.** `ShotTargeting` maps a `Shot` to a
court point, and `ShotAiming` de-collides the four so two options can never draw
one ring on top of another (the attack phase really does offer both "Put it
away, at their feet" and "Drive, at their feet"). De-collide in COURT space
only; screen space is `AimLabelLayout`'s job, and conflating them is what made
all four captions pile into one unhittable stack at forty feet of depth. The
fan lays a cluster out around its centre and slides the whole run inside the
sidelines, because clamping each member independently collapsed the fan
whenever it sat near an edge.

### SceneKit accessibility

- **SceneKit publishes an accessibility element per node.** The court exported
  roughly two hundred unlabelled elements (forty net strands, every line box,
  both players' limbs); VoiceOver had to be swiped through all of it and
  XCUITest queries slowed to the point of timing out. `.accessibilityHidden` on
  the SwiftUI wrapper does not reach inside a hosted `UIView`, so `SCNView`
  gets `accessibilityElementsHidden` directly.
