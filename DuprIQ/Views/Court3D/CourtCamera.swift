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

    /// How far behind your own contact point the eye sits, in feet. Small: this
    /// is your head, not a camera on a boom.
    static let shoulderOffset: Double = 1.6

    /// The narrowest and widest vertical angles the fit below is allowed to
    /// choose. Below the floor the court stops feeling like a place; above the
    /// ceiling the edges of a phone frame distort badly enough to misrepresent
    /// where someone is standing, which is the one thing this view must not do.
    static let minimumFieldOfView: Double = 58
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
    /// **The ball has to be in front of it.** `you` and `contact` are generated
    /// independently, so a legal position can put the ball level with your own
    /// shoes, which the overhead diagram drew without complaint and which in
    /// first person would put the ball inside the lens.
    ///
    /// **The angle is fitted, not fixed.** A single field of view cannot serve
    /// both ends of the court. From your own baseline everything is far away
    /// and a narrow angle is right; from the kitchen line an opponent at the
    /// far sideline is forty-odd degrees off your nose, and a fixed angle put
    /// them off the edge of the screen. `CourtCameraTests` pins that down for
    /// every phase, because it is invisible until it is the one ball where the
    /// read was a player you could not see.
    static func viewing(
        _ position: RallyPosition, aspect: Double = defaultAspect
    ) -> CourtCamera {
        let mustSee = framingPoints(for: position)
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

    /// Everything that has to be inside the frame: both opponents head to toe,
    /// the ball, and the whole region an aim ring can land in for this
    /// position. The aim region is derived rather than passed in, so the camera
    /// does not have to know which four options the generator happened to pick.
    private static func framingPoints(
        for position: RallyPosition
    ) -> [(point: CourtPoint, height: Double)] {
        var points: [(CourtPoint, Double)] = []

        for side in OpponentSide.allCases {
            let opponent = position.opponent(side)
            points.append((opponent, 0))
            points.append((opponent, 5.6))
        }
        points.append((position.contact, ballHeightForFraming(position.ballHeight)))

        let contactIsLeft = position.contact.isLeftHalf
        // Each candidate x, plus the room `ShotAiming` needs to fan two rings
        // apart when two options land on the same spot. Without the spread the
        // fit was computed against where a shot lands and the ring was then
        // drawn up to three feet to the side of it, off the frame.
        let spread = ShotAiming.maximumFanOffset
        let baseXs: [Double] = [
            contactIsLeft ? CourtGeometry.width * 0.75 : CourtGeometry.width * 0.25,
            contactIsLeft ? CourtGeometry.width * 0.25 : CourtGeometry.width * 0.75,
            CourtGeometry.centerX,
            position.opponentLeft.x, position.opponentRight.x,
            position.opponentLeft.x + 2.4, position.opponentRight.x + 2.4,
        ]
        let xs = baseXs.flatMap { [$0 - spread, $0, $0 + spread] }
        let ys: [Double] = [
            CourtGeometry.netY + 2.6,
            CourtGeometry.length - 4.0,
            position.opponentLeft.y - 1.4,
            position.opponentRight.y - 1.4,
        ]
        for x in xs {
            for y in ys {
                points.append((CourtPoint(
                    x: min(max(x, 1.2), CourtGeometry.width - 1.2),
                    y: min(max(y, CourtGeometry.netY + 1.2), CourtGeometry.length - 1.2)
                ), 0))
            }
        }
        return points.map { (point: $0.0, height: $0.1) }
    }

    /// Mirrors `CourtScene.ballHeight`. Duplicated deliberately: the camera is
    /// in the model layer of this feature and must not depend on the renderer,
    /// and `CourtCameraTests` asserts the ball is in frame using the renderer's
    /// value, so the two cannot drift apart unnoticed.
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
        // Far enough back that the ball is a thing you look at rather than a
        // sphere filling the lens.
        let minimumReach = 4.5
        let standing = min(position.you.y, position.contact.y - minimumReach)
        let eyeY = max(-9.0, standing - shoulderOffset - pullBack)
        // Line the eye up behind the CONTACT, not behind your feet.
        //
        // You turn your shoulders to the ball before you hit it. Lining up on
        // `you`, or splitting the difference, put the ball at an impossible
        // angle whenever the two were far apart: the generator treats
        // `you` and `contact` as independent draws, so it can place a contact
        // eight feet to the side of the player, which at six feet of depth is
        // fifty-odd degrees off the nose and outside any sane frame. The
        // overhead diagram hid that by drawing two dots. Centring on the
        // contact makes the ball framing independent of it.
        let eye = CourtPoint(x: position.contact.x, y: eyeY)
        let eyeHeight = 5.9

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

        // Spend the surplus on court, not on sky.
        //
        // A portrait phone is twice as tall as it is wide, so the angle needed
        // to fit the court's WIDTH forces a vertical angle far larger than the
        // subject needs. Centring the head on the subject then splits that
        // surplus evenly and the half above the horizon is empty darkness, a
        // third of the screen on every ball. Tilting down until the horizon
        // sits near the top moves all of it below the skyline, where at worst
        // it is your own court. The clamps keep the subject inside the frame,
        // so this only ever reallocates space the fit proved was spare.
        var pitch = (minV + maxV) / 2
        var fov = minimumFieldOfView
        for _ in 0..<4 {
            fov = fit(pitch: pitch)
            let half = fov * .pi / 180 / 2
            pitch = min(max(0.74 * half, maxV - half), minV + half)
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
