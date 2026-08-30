import CoreGraphics
import Foundation
import SceneKit

/// The eye the rally is seen through, and the projection that puts a court
/// point on the screen.
///
/// Two things need to agree about where a point in the world lands: SceneKit,
/// which draws the court, the players and the ball, and SwiftUI, which draws
/// every piece of text and every tappable target on top. Rather than ask
/// SceneKit for `projectPoint` (whose viewport convention has bitten enough
/// people that it is not worth the ambiguity here) this struct owns the camera
/// completely: it configures the `SCNCamera` AND does the projection itself,
/// from the same numbers. If the labels line up with the rings SceneKit drew,
/// the two agree, and that is visible in one screenshot.
struct CourtCamera {
    /// Eye position in court feet. May sit behind your own baseline, which is
    /// a legal place to stand and a better place to watch from.
    let eye: CourtPoint
    /// Eye height above the surface, in feet.
    let eyeHeight: Double
    /// How far the head is tilted down, in radians. Positive looks down.
    let pitch: Double
    /// VERTICAL field of view, in degrees.
    ///
    /// Vertical and not horizontal, and this is the single most consequential
    /// number on this screen. A phone is roughly twice as tall as it is wide,
    /// so locking a comfortable horizontal angle produces a vertical one near
    /// 120 degrees: the far court collapses into a thin band at the horizon and
    /// the frame fills with empty sky and empty near court. Locking the
    /// vertical angle instead puts the opponents' end of the court, which is
    /// the thing being read, across the frame.
    let verticalFieldOfView: Double

    /// Which way the head is turned, in radians, so the court is centred in
    /// the frame instead of sitting off to one side.
    ///
    /// Without this the camera always stared straight down the court axis, so
    /// standing anywhere but the centre line pushed the whole court into one
    /// half of the screen and left the other half as empty apron. A player
    /// looks at where they are hitting, not at the wall in front of them.
    let yaw: Double

    /// How far behind your own stance the eye sits, in feet.
    ///
    /// This used to be 1.6, i.e. a head on a body, and it produced a frame
    /// nobody could read. From five feet away a ball at 1.7 ft sits forty
    /// degrees below the horizon while the opponents sit on it, so the two
    /// things the question compares (this ball, and the net over there) end up
    /// at opposite ends of the screen with thirty percent of the frame of
    /// empty near court between them. Stepping the eye back to a shoulder's
    /// view closes that gap: the same ball is now twenty-five degrees down and
    /// the whole subject fits in one glance.
    ///
    /// The read this used to protect, how close YOU are to the kitchen, is not
    /// lost. `CourtScene` draws a ring on the paint where you are standing, so
    /// your own position is a thing you can see rather than a thing inferred
    /// from how low the camera is.
    static let shoulderOffset: Double = 8.5

    /// The smallest slice of the frame the fit is willing to aim at.
    ///
    /// The chrome bands are passed in as fractions and a caller can, in a very
    /// short box, ask for more chrome than there is frame. Rather than solve an
    /// impossible constraint and return a camera pointing at nothing, the fit
    /// falls back to the whole frame.
    static let minimumBandHeight: Double = 0.24

    /// The narrowest and widest vertical angles the fit below is allowed to
    /// choose. Below the floor the court stops feeling like a place; above the
    /// ceiling the edges of a phone frame distort badly enough to misrepresent
    /// where someone is standing, which is the one thing this view must not do.
    /// The floor was 58, chosen when the fit was framing a synthetic region
    /// spanning the whole far court and therefore never came near it. Now that
    /// the fit sees only the four rings this question draws, 58 was the binding
    /// constraint on most balls and it was throwing away the reach it had
    /// earned: the opponents and the rings sat small in the middle of the frame
    /// with nothing gained. The clamps below are guard rails, not a look.
    static let minimumFieldOfView: Double = 46
    static let maximumFieldOfView: Double = 92

    /// The aspect ratio the camera is fitted for when the caller has not
    /// measured one yet. A portrait phone, which is the tight case.
    static let defaultAspect: Double = 402.0 / 874.0

    /// The camera for a position, fitted to what has to be visible.
    ///
    /// Three rules, all of them forced by geometry rather than taste.
    ///
    /// **It stays at head height, and the net is see-through.** An earlier
    /// version raised the eye to twelve feet so the sightline would clear the
    /// net tape, on the reasoning that a 34 inch net hides the far kitchen from
    /// anyone at their own baseline. The reasoning was right and the fix was
    /// wrong: a pickleball net is a MESH, drawn as one in `CourtScene`, and you
    /// look through it. The eye stays where a head is.
    ///
    /// **The ball has to be in front of it.** The contact is a reach from your
    /// stance rather than an independent draw, so this is a step back rather
    /// than a rescue, but a ball level with the lens is unrecoverable.
    ///
    /// **The angle is fitted, not fixed.** A single field of view cannot serve
    /// both ends of the court. From your own baseline everything is far away
    /// and a narrow angle is right; from the kitchen line an opponent at the
    /// far sideline is forty-odd degrees off your nose, and a fixed angle put
    /// them off the edge of the screen. `CourtCameraTests` pins that down for
    /// every phase, because it is invisible until it is the one ball where the
    /// read was a player you could not see.
    /// **The chrome is part of the frame.** `topFraction` and `bottomFraction`
    /// are the slices of the rendered frame that something else is drawn over:
    /// the HUD at the top, and the option panel (or the verdict card that
    /// replaces it) at the bottom. The scene still fills the whole view, so the
    /// court runs edge to edge under both, but nothing the question is ABOUT is
    /// allowed to land under them. Fitting to the full frame and then covering
    /// a third of it is how the build before this one ended up with all four
    /// rings, both opponents and the ball squeezed into a band a fifth of the
    /// screen tall with half the display showing empty near court.
    static func viewing(
        _ position: RallyPosition,
        aiming aimPoints: [CourtPoint] = [],
        aspect: Double = defaultAspect,
        topFraction: Double = 0,
        bottomFraction: Double = 0
    ) -> CourtCamera {
        let mustSee = framingPoints(for: position, aiming: aimPoints)
        let band = Band(top: topFraction, bottom: bottomFraction)
        var pullBack = 0.0

        // Widen first; only walk the eye backwards when widening runs out. A
        // pulled-back eye misrepresents how close YOU are to the kitchen, which
        // is itself a read in the transition phase, so it is the second lever
        // rather than the first.
        for step in 0...6 {
            let camera = fitted(
                position, pullBack: pullBack, aspect: aspect, band: band, mustSee: mustSee
            )
            if camera.verticalFieldOfView < maximumFieldOfView || step == 6 {
                return camera
            }
            pullBack += 2.5
        }
        return fitted(
            position, pullBack: pullBack, aspect: aspect, band: band, mustSee: mustSee
        )
    }

    /// The camera for a whole question, which knows where its four rings are.
    static func viewing(
        _ question: DrillQuestion,
        aspect: Double = defaultAspect,
        topFraction: Double = 0,
        bottomFraction: Double = 0
    ) -> CourtCamera {
        viewing(
            question.position,
            aiming: ShotAiming.aimPoints(
                for: question.options, in: question.position,
                answer: question.answer,
                answerTarget: question.verdict.targetOpponent
            ),
            aspect: aspect,
            topFraction: topFraction,
            bottomFraction: bottomFraction
        )
    }

    /// The strip of the frame the subject is allowed to occupy, in normalised
    /// device coordinates where +1 is the top of the frame and -1 the bottom.
    ///
    /// Working in NDC rather than in points keeps this independent of how big
    /// the view is, and it is the space the projection already speaks: a point
    /// is in the band exactly when its projected `ndcY` is between the two.
    struct Band {
        let top: Double
        let bottom: Double

        init(top topFraction: Double, bottom bottomFraction: Double) {
            let t = max(0, min(topFraction, 0.6))
            let b = max(0, min(bottomFraction, 0.6))
            if 1 - t - b < CourtCamera.minimumBandHeight {
                self.top = 1
                self.bottom = -1
            } else {
                self.top = 1 - 2 * t
                self.bottom = -1 + 2 * b
            }
        }

        var centre: Double { (top + bottom) / 2 }
    }

    /// Everything that has to be inside the frame: both opponents head to toe,
    /// the ball, and the four rings this question actually draws.
    ///
    /// The four rings are PASSED IN now. The first version derived a synthetic
    /// grid of every place any option could ever land, which spanned almost the
    /// whole far court on every single ball, so the fit below ran into its
    /// widest allowed angle every time and squeezed the real subject into a
    /// band across the top of the screen. Framing what is drawn instead of what
    /// might have been drawn is most of the difference between the two builds.
    private static func framingPoints(
        for position: RallyPosition, aiming aimPoints: [CourtPoint]
    ) -> [(point: CourtPoint, height: Double)] {
        var points: [(CourtPoint, Double)] = []

        for side in OpponentSide.allCases {
            let opponent = position.opponent(side)
            points.append((opponent, 0))
            points.append((opponent, 5.6))
            for height in [opponentRingBottomForFraming, opponentRingTopForFraming] {
                points.append(contentsOf: ringPoints(
                    around: opponent, radius: opponentRingRadiusForFraming, height: height
                ))
            }
        }
        // Both the ball and the tape reference beside it: the comparison
        // between the two is the question, so half of it in frame is no use.
        points.append((position.contact, ballHeightForFraming(position.ballHeight)))
        points.append((position.contact, netHeightForFraming))
        points.append((position.contact, 0))
        for xOffset in [-netHeightBarHalfWidthForFraming, netHeightBarHalfWidthForFraming] {
            for yOffset in [-netHeightBarHalfLengthForFraming, netHeightBarHalfLengthForFraming] {
                for heightOffset in [-netHeightBarHalfHeightForFraming, netHeightBarHalfHeightForFraming] {
                    points.append((
                        CourtPoint(x: position.contact.x + xOffset, y: position.contact.y + yOffset),
                        netHeightForFraming + heightOffset
                    ))
                }
            }
        }
        let ballHeight = ballHeightForFraming(position.ballHeight)
        for xOffset in [-ballRadiusForFraming, ballRadiusForFraming] {
            for yOffset in [-ballRadiusForFraming, ballRadiusForFraming] {
                for heightOffset in [-ballRadiusForFraming, ballRadiusForFraming] {
                    points.append((
                        CourtPoint(
                            x: position.contact.x + xOffset,
                            y: position.contact.y + yOffset
                        ),
                        ballHeight + heightOffset
                    ))
                }
            }
        }
        // Your own feet, so the ring `CourtScene` draws under them is somewhere
        // you can actually see. Without it the stance ring fell off the left
        // edge whenever you were reaching to the side, which is exactly when
        // knowing where your feet are matters.
        points.append((position.you, 0))
        for height in [stanceRingBottomForFraming, stanceRingTopForFraming] {
            points.append(contentsOf: ringPoints(
                around: position.you, radius: stanceRingRadiusForFraming, height: height
            ))
        }

        // The whole ring, not just its centre. The emphasized ring is over
        // three feet across, and the fit follows its perimeter rather than a
        // bounding square whose corners are not on the rendered torus.
        // On a portrait phone the four rings' width is what sets the field of
        // view, so fitting the actual perimeter keeps the option visible
        // without widening the angle for empty space.
        for point in aimPoints {
            points.append((point, 0))
            for height in [aimRingBottomForFraming, aimRingTopForFraming] {
                points.append(contentsOf: ringPoints(
                    around: point, radius: aimRingRadiusForFraming, height: height
                ))
            }
        }

        // A fallback for callers with no options to hand (previews, and the
        // camera tests that only care about the players). The far kitchen and
        // the two deep corners are where a ring can be.
        if aimPoints.isEmpty {
            for x in [CourtGeometry.width * 0.25, CourtGeometry.centerX,
                      CourtGeometry.width * 0.75] {
                for y in [CourtGeometry.netY + 2.6, CourtGeometry.length - 4.0] {
                    points.append((CourtPoint(x: x, y: y), 0))
                }
            }
        }
        return points.map { (point: $0.0, height: $0.1) }
    }

    /// Mirrors `CourtScene.ballHeight`. Duplicated deliberately: the camera is
    /// in the model layer of this feature and must not depend on the renderer,
    /// and `CourtCameraTests` asserts the ball is in frame using the renderer's
    /// value, so the two cannot drift apart unnoticed.
    /// The net tape, which `CourtScene` also draws as a reference hoop beside
    /// the ball. Same duplication argument as `ballHeightForFraming`.
    private static let netHeightForFraming: Double = 34.0 / 12.0

    /// Mirrors the largest ring `CourtScene.aimTarget` draws, plus its pipe:
    /// `ringRadius 1.65 + pipeRadius 0.15`.
    private static let aimRingRadiusForFraming: Double = 1.8

    /// The perimeter sample count used to fit each horizontal torus. Four
    /// cardinal points are not enough once yaw and pitch turn the ellipse on
    /// screen, so the fit follows the rendered ring around its full edge.
    private static let ringSampleCount = 16

    /// Mirrors the outer edge of the ring under each opponent:
    /// `ringRadius 1.05 + pipeRadius 0.075`.
    private static let opponentRingRadiusForFraming: Double = 1.125

    /// The torus is centred at 0.07 ft and its pipe is 0.075 ft thick.
    private static let opponentRingBottomForFraming: Double = -0.005
    private static let opponentRingTopForFraming: Double = 0.145

    /// Mirrors the outer edge of the quiet ring under the player:
    /// `ringRadius 0.9 + pipeRadius 0.035`.
    private static let stanceRingRadiusForFraming: Double = 0.935

    /// The stance torus is centred at 0.07 ft and its pipe is 0.035 ft thick.
    private static let stanceRingBottomForFraming: Double = 0.035
    private static let stanceRingTopForFraming: Double = 0.105

    /// Mirrors half the dark backing bar beside the ball:
    /// `width 1.14 / 2`.
    private static let netHeightBarHalfWidthForFraming: Double = 0.57

    /// Mirrors half the dark backing bar's depth:
    /// `length 0.19 / 2`.
    private static let netHeightBarHalfLengthForFraming: Double = 0.095

    /// The cap is taller than the backing bar, so it defines the vertical
    /// extent that has to remain visible.
    private static let netHeightBarHalfHeightForFraming: Double = 0.12

    /// Mirrors the radius of the rendered ball sphere.
    private static let ballRadiusForFraming: Double = 0.22

    /// The largest aim torus is centred at 0.09 ft and has a 0.15 ft pipe.
    private static let aimRingBottomForFraming: Double = -0.06
    private static let aimRingTopForFraming: Double = 0.24

    private static func ringPoints(
        around centre: CourtPoint, radius: Double, height: Double
    ) -> [(point: CourtPoint, height: Double)] {
        (0..<ringSampleCount).map { sample in
            let angle = Double(sample) * 2 * .pi / Double(ringSampleCount)
            return (
                point: CourtPoint(
                    x: centre.x + cos(angle) * radius,
                    y: centre.y + sin(angle) * radius
                ),
                height: height
            )
        }
    }

    private static func ballHeightForFraming(_ height: BallHeight) -> Double {
        switch height {
        case .belowNet: return 1.7
        case .netHeight: return 2.9
        case .aboveNet: return 4.3
        }
    }

    private static func fitted(
        _ position: RallyPosition,
        pullBack: Double,
        aspect: Double,
        band: Band,
        mustSee: [(point: CourtPoint, height: Double)]
    ) -> CourtCamera {
        // Behind your own stance, and never level with the ball. The contact is
        // generated as a reach from `you` now, so the two are always within a
        // stride of each other and this is a step back rather than a rescue.
        let standing = min(position.you.y, position.contact.y - 0.8)
        let eyeY = max(-13.0, standing - shoulderOffset - pullBack)
        // Behind YOUR FEET, not behind the ball.
        //
        // Lining the eye up on the contact was an attempt to model turning your
        // shoulders to the ball, and it moved the wrong thing: your own stance
        // ring slid off to one side of the frame by the whole width of your
        // reach, so on a screenshot the ball looked like it belonged to
        // somebody else. A head sits over its own feet. The ball being off to
        // one side IS the read when you are reaching for it, and `yaw` below
        // still turns the head far enough to keep everything centred.
        let eye = CourtPoint(x: position.you.x, y: eyeY)
        // A shade under standing height. The ball is the low thing in this
        // frame and the far court is the high thing, so every inch the eye
        // comes down pulls the two closer together: at 5.9 a ball on your
        // shoetops sat thirty degrees below the court you were aiming at, and
        // the frame had to stretch across both.
        let eyeHeight = 5.2

        // Centre the head on what has to be seen, rather than pointing it at a
        // fixed spot and hoping.
        var minH = Double.greatestFiniteMagnitude, maxH = -Double.greatestFiniteMagnitude
        var minV = Double.greatestFiniteMagnitude, maxV = -Double.greatestFiniteMagnitude
        for entry in mustSee {
            let dx = entry.point.x - eye.x
            let forward = entry.point.y - eye.y
            guard forward > 0.4 else { continue }
            let h = atan2(dx, forward)
            let v = atan2(eyeHeight - entry.height, (dx * dx + forward * forward).squareRoot())
            minH = min(minH, h); maxH = max(maxH, h)
            minV = min(minV, v); maxV = max(maxV, v)
        }
        guard minH <= maxH else {
            return CourtCamera(
                eye: eye, eyeHeight: eyeHeight, pitch: 20 * .pi / 180,
                verticalFieldOfView: minimumFieldOfView, yaw: 0
            )
        }

        let yaw = -(minH + maxH) / 2

        /// The narrowest vertical angle that lands every point inside the band.
        ///
        /// A point projects to `ndcY = (y / depth) / tan(halfV)`, so requiring
        /// `ndcY` to stay between the band's edges is one division per point
        /// rather than a search. Above the frame's centre the top edge binds,
        /// below it the bottom edge does, and the horizontal constraint is the
        /// same sum scaled by the aspect ratio. This is why the band has to be
        /// an input to the fit and cannot be applied afterwards: shrinking the
        /// usable strip widens the angle, and widening the angle moves every
        /// point.
        func fit(pitch: Double) -> Double {
            let probe = CourtCamera(
                eye: eye, eyeHeight: eyeHeight, pitch: pitch,
                verticalFieldOfView: minimumFieldOfView, yaw: yaw
            )
            var needed = 0.0
            for entry in mustSee {
                guard let camera = probe.cameraSpace(entry.point, height: entry.height) else { continue }
                let up = camera.y / camera.depth
                if up >= 0 {
                    needed = max(needed, up / max(band.top, 0.08))
                } else {
                    needed = max(needed, up / min(band.bottom, -0.08))
                }
                needed = max(needed, abs(camera.x) / camera.depth / max(aspect, 0.05))
            }
            // A little room so nothing sits exactly on the edge of the band.
            return min(
                max(2 * atan(needed * 1.06) * 180 / .pi, minimumFieldOfView),
                maximumFieldOfView
            )
        }

        // Put the subject in the middle of the band, then hold it there.
        //
        // Pitch and field of view depend on each other: tilting changes the
        // depth to every point, which changes the angle needed to contain them,
        // so applying the tilt after the fit leaves points outside the frame.
        // Four passes is enough for the two to settle, and the clamps are
        // containment (a point may never leave the band) while the target is
        // composition (the subject would like to be centred in it).
        let subjectCentre = (minV + maxV) / 2
        var pitch = subjectCentre
        var fov = minimumFieldOfView
        for _ in 0..<5 {
            fov = fit(pitch: pitch)
            let tanHalf = tan(fov * .pi / 180 / 2)
            pitch = min(
                max(subjectCentre + atan(band.centre * tanHalf),
                    maxV + atan(band.bottom * tanHalf * 0.98)),
                minV + atan(band.top * tanHalf * 0.98)
            )
        }
        // One last fit at the pitch actually being used, so containment is a
        // property of the returned camera rather than of the last iteration.
        fov = max(fov, fit(pitch: pitch))

        return CourtCamera(
            eye: eye, eyeHeight: eyeHeight, pitch: pitch,
            verticalFieldOfView: fov, yaw: yaw
        )
    }

    // MARK: - Scene space
    //
    // Court feet to SceneKit units, one to one. x runs across the court with
    // the center line at zero; the camera looks down -z, so a court y of 44
    // (their baseline) sits at z = -44, far in front.

    static func scenePoint(x: Double, y: Double, height: Double = 0) -> SCNVector3 {
        SCNVector3(Float(x - CourtGeometry.centerX), Float(height), Float(-y))
    }

    static func scenePoint(_ point: CourtPoint, height: Double = 0) -> SCNVector3 {
        scenePoint(x: point.x, y: point.y, height: height)
    }

    var scenePosition: SCNVector3 {
        Self.scenePoint(eye, height: eyeHeight)
    }

    /// Configures a `SCNCamera` to match this struct exactly. `.vertical`
    /// matters: see `verticalFieldOfView`.
    func apply(to camera: SCNCamera) {
        camera.fieldOfView = CGFloat(verticalFieldOfView)
        camera.projectionDirection = .vertical
        camera.zNear = 0.05
        camera.zFar = 320
        camera.wantsHDR = false
    }

    var eulerAngles: SCNVector3 { SCNVector3(Float(-pitch), Float(yaw), 0) }

    // MARK: - Projection

    /// Where a court point lands on screen, or nil when it is behind the eye.
    ///
    /// `height` is feet above the surface, so a player's head and the ball can
    /// be projected as easily as a spot on the paint.
    /// A world point in the camera's own frame, or nil when it is behind the
    /// eye. Both the projection and the field-of-view fit go through here, so
    /// the angle chosen to contain a point and the place that point is drawn
    /// can never be computed two different ways.
    func cameraSpace(
        _ point: CourtPoint, height: Double = 0
    ) -> (x: Double, y: Double, depth: Double)? {
        // World -> camera, undoing the yaw and then the pitch. Order matters
        // and it is the reverse of how the node is oriented: with roll at zero
        // SceneKit composes as pitch * yaw, so the inverse is yaw then pitch.
        let dx = point.x - eye.x
        let dy = height - eyeHeight
        let dz = -(point.y) - (-(eye.y))

        let cw = cos(yaw), sw = sin(yaw)
        let rx = dx * cw - dz * sw
        let rz = dx * sw + dz * cw

        let c = cos(pitch), s = sin(pitch)
        let cy = dy * c - rz * s
        let cz = dy * s + rz * c

        // The camera looks down -z, so depth in front is -cz.
        let depth = -cz
        guard depth > 0.05 else { return nil }
        return (rx, cy, depth)
    }

    func project(
        _ point: CourtPoint, height: Double = 0, in size: CGSize
    ) -> CGPoint? {
        guard size.width > 0, size.height > 0,
              let camera = cameraSpace(point, height: height) else { return nil }

        let tanHalfV = tan(verticalFieldOfView * .pi / 180 / 2)
        let tanHalfH = tanHalfV * Double(size.width / size.height)

        let ndcX = (camera.x / camera.depth) / tanHalfH
        let ndcY = (camera.y / camera.depth) / tanHalfV

        return CGPoint(
            x: (ndcX + 1) / 2 * Double(size.width),
            y: (1 - ndcY) / 2 * Double(size.height)
        )
    }

    /// How far a court point is from the eye, for sizing an overlay so a distant
    /// label does not shout as loudly as a near one.
    func distance(to point: CourtPoint) -> Double {
        let dx = point.x - eye.x
        let dy = point.y - eye.y
        return (dx * dx + dy * dy).squareRoot()
    }
}
