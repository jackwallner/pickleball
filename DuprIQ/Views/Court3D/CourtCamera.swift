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

    /// Where the subject's vertical centre should sit in the frame, measured
    /// from the top.
    ///
    /// The previous build aimed the surplus at the top of the frame on the
    /// reasoning that empty sky is worse than empty court. It is, but the
    /// version that fixed it went too far and pinned the opponents into the
    /// top fifth of the screen with the ball alone at the bottom. Just above
    /// centre is the honest answer: the HUD lives in the band above, and the
    /// four captions live in the near court below.
    static let subjectCentreFraction: Double = 0.46

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
    static func viewing(
        _ position: RallyPosition,
        aiming aimPoints: [CourtPoint] = [],
        aspect: Double = defaultAspect
    ) -> CourtCamera {
        let mustSee = framingPoints(for: position, aiming: aimPoints)
        var pullBack = 0.0

        // Widen first; only walk the eye backwards when widening runs out. A
        // pulled-back eye misrepresents how close YOU are to the kitchen, which
        // is itself a read in the transition phase, so it is the second lever
        // rather than the first.
        for step in 0...6 {
            let camera = fitted(position, pullBack: pullBack, aspect: aspect, mustSee: mustSee)
            if camera.verticalFieldOfView < maximumFieldOfView || step == 6 {
                return camera
            }
            pullBack += 2.5
        }
        return fitted(position, pullBack: pullBack, aspect: aspect, mustSee: mustSee)
    }

    /// The camera for a whole question, which knows where its four rings are.
    static func viewing(
        _ question: DrillQuestion, aspect: Double = defaultAspect
    ) -> CourtCamera {
        viewing(
            question.position,
            aiming: ShotAiming.aimPoints(
                for: question.options, in: question.position,
                answer: question.answer,
                answerTarget: question.verdict.targetOpponent
            ),
            aspect: aspect
        )
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
        }
        // Both the ball and the tape reference beside it: the comparison
        // between the two is the question, so half of it in frame is no use.
        points.append((position.contact, ballHeightForFraming(position.ballHeight)))
        points.append((position.contact, netHeightForFraming))
        points.append((position.contact, 0))
        // Your own feet, so the ring `CourtScene` draws under them is somewhere
        // you can actually see. Without it the stance ring fell off the left
        // edge whenever you were reaching to the side, which is exactly when
        // knowing where your feet are matters.
        points.append((position.you, 0))

        // The whole ring, not just its centre. The fit used to frame the point
        // a shot lands on, and the ring drawn around it is nearly two feet
        // across: on the App Store capture the outermost option was a yellow
        // arc sliced off by the right edge of the screen.
        for point in aimPoints {
            for dx in [-aimRingRadiusForFraming, 0, aimRingRadiusForFraming] {
                for dy in [-aimRingRadiusForFraming, 0, aimRingRadiusForFraming] {
                    points.append((CourtPoint(x: point.x + dx, y: point.y + dy), 0))
                }
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

    /// Mirrors the largest ring `CourtScene.aimTarget` draws, plus its pipe.
    private static let aimRingRadiusForFraming: Double = 1.8

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
        mustSee: [(point: CourtPoint, height: Double)]
    ) -> CourtCamera {
        // Behind your own stance, and never level with the ball. The contact is
        // generated as a reach from `you` now, so the two are always within a
        // stride of each other and this is a step back rather than a rescue.
        let standing = min(position.you.y, position.contact.y - 0.8)
        let eyeY = max(-13.0, standing - shoulderOffset - pullBack)
        // Line the eye up behind the CONTACT, not behind your feet: you turn
        // your shoulders to the ball before you hit it.
        let eye = CourtPoint(x: position.contact.x, y: eyeY)
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

        // Pitch and field of view depend on each other, so they are solved
        // together rather than one after the other.
        //
        // The angle has to be wide enough to contain the subject, and the head
        // wants to be tilted down far enough that the frame's surplus lands on
        // court instead of on empty sky. But tilting changes the depth to every
        // point, which changes the angle needed to contain them: applying the
        // tilt after the fit left points a few pixels outside the frame, which
        // `CourtCameraTests` caught and an eye would not have.
        func fit(pitch: Double) -> Double {
            let probe = CourtCamera(
                eye: eye, eyeHeight: eyeHeight, pitch: pitch,
                verticalFieldOfView: minimumFieldOfView, yaw: yaw
            )
            var neededTanH = 0.0, neededTanV = 0.0
            for entry in mustSee {
                guard let camera = probe.cameraSpace(entry.point, height: entry.height) else { continue }
                neededTanH = max(neededTanH, abs(camera.x) / camera.depth)
                neededTanV = max(neededTanV, abs(camera.y) / camera.depth)
            }
            // A little room so nothing sits exactly on the edge of the frame.
            let tanHalfV = max(neededTanV, neededTanH / max(aspect, 0.05)) * 1.10
            return min(
                max(2 * atan(tanHalfV) * 180 / .pi, minimumFieldOfView),
                maximumFieldOfView
            )
        }

        // Put the subject where the eye looks, and spend the surplus on the two
        // things that want it.
        //
        // A portrait phone is twice as tall as it is wide, so the angle needed
        // to fit the court's WIDTH always leaves vertical room to spare. The
        // build before this one pushed all of that spare room downward, which
        // pinned the opponents and all four rings into a band across the top
        // fifth of the screen with nothing but empty near court under them.
        // Landing the subject's centre just above the middle of the frame gives
        // the HUD a dark band to sit in and leaves the near court below the
        // rings for the four captions, which is exactly where they belong.
        //
        // The clamps still win: they only ever give back space the fit proved
        // was spare, so containment is never traded for composition.
        let subjectCentre = (minV + maxV) / 2
        let offset = 1 - 2 * subjectCentreFraction
        var pitch = subjectCentre
        var fov = minimumFieldOfView
        for _ in 0..<4 {
            fov = fit(pitch: pitch)
            let half = fov * .pi / 180 / 2
            pitch = min(
                max(subjectCentre + offset * half, maxV - half * 0.96),
                minV + half * 0.96
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
