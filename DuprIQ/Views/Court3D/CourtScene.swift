import SceneKit
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Builds the rally as a real court you are standing on.
///
/// Everything here is procedural: boxes, capsules, spheres and tori, sized in
/// court feet from `CourtGeometry`. There is not one imported model or texture,
/// which keeps the binary the size it was and means the court can never drift
/// out of step with the rulebook the advisor reasons about.
///
/// What the scene deliberately does NOT draw is text. Labels, the four aim
/// targets' captions and the player initials are SwiftUI on top, projected
/// through `CourtCamera`, because native text is crisp, honours Dynamic Type,
/// and is reachable by VoiceOver. SceneKit draws the world; SwiftUI names it.
enum CourtScene {

    /// Heights the ball can be at contact, in feet.
    ///
    /// These are the whole point of rendering in first person. The old diagram
    /// printed "Above net height" as a caption, which meant the single fact the
    /// answer turns on was read off a label rather than seen. Here the ball
    /// hangs at an actual height next to a net whose tape is at a known one, so
    /// "is this attackable" becomes something you look at.
    static func ballHeight(_ height: BallHeight) -> Double {
        switch height {
        case .belowNet: return 1.7
        case .netHeight: return 2.9
        case .aboveNet: return 4.3
        }
    }

    /// Net dimensions. 36 inches at the posts, 34 at the center; the sag is
    /// approximated with a flat panel at the center height, because a curved
    /// net would cost a custom geometry to buy a detail nobody reads.
    static let netHeight: Double = 34.0 / 12.0
    static let postHeight: Double = 36.0 / 12.0

    // MARK: - Assembly

    /// There is no longer a paddle held in the corner of the frame.
    ///
    /// It was a nice first-person flourish and it is now dead geometry: the
    /// bottom third of the screen is the option panel, which is where the
    /// paddle hung. Half-covered by the panel it read as a dark slab being
    /// clipped, which is the exact failure the comment on the old version
    /// warned about in a session runner. Your own presence is carried by the
    /// camera position. The partner marker remains in the scene when it can be
    /// shown without obscuring the read.
    static func make(for position: RallyPosition, camera: CourtCamera) -> SCNScene {
        let scene = SCNScene()
        let root = scene.rootNode

        scene.background.contents = skyGradient()
        root.addChildNode(cameraNode(camera))
        addLighting(to: root)
        addGround(to: root)
        addLines(to: root)
        addNet(to: root)
        addSurround(to: root)

        root.addChildNode(player(at: position.opponentLeft, kind: .opponent))
        root.addChildNode(player(at: position.opponentRight, kind: .opponent))
        // A nearby full body blocks the court, but the partner's feet are still
        // part of the position. Use an exact floor marker until there is room
        // to draw the whole player without covering the ball or an aim ring.
        if camera.distance(to: position.partner) > minimumFullBodyDistance {
            root.addChildNode(player(at: position.partner, kind: .partner))
        } else {
            root.addChildNode(footprint(at: position.partner, kind: .partner))
        }
        root.addChildNode(ball(at: position.contact, height: ballHeight(position.ballHeight)))

        return scene
    }

    /// The dark above the fence.
    ///
    /// A flat fill up there reads as an unpainted region rather than as a room,
    /// so the backdrop is a vertical ramp from near black at the top down to
    /// the colour of the surround, which is what an indoor court under lights
    /// actually looks like from the baseline.
    private static func skyGradient() -> UIImage {
        let size = CGSize(width: 4, height: 256)
        return UIGraphicsImageRenderer(size: size).image { context in
            let colors = [
                UIColor(red: 0.018, green: 0.043, blue: 0.055, alpha: 1).cgColor,
                UIColor(red: 0.028, green: 0.075, blue: 0.085, alpha: 1).cgColor,
                UIColor(red: 0.055, green: 0.140, blue: 0.140, alpha: 1).cgColor,
            ]
            guard let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors as CFArray,
                locations: [0, 0.62, 1]
            ) else { return }
            context.cgContext.drawLinearGradient(
                gradient,
                start: .zero,
                end: CGPoint(x: 0, y: size.height),
                options: []
            )
        }
    }

    static func cameraNode(_ camera: CourtCamera) -> SCNNode {
        let node = SCNNode()
        let scnCamera = SCNCamera()
        camera.apply(to: scnCamera)
        node.camera = scnCamera
        node.position = camera.scenePosition
        node.eulerAngles = camera.eulerAngles
        node.name = "camera"
        return node
    }

    // MARK: - Lighting

    private static func addLighting(to root: SCNNode) {
        // Court lights: one key from high and behind the far baseline, plus
        // enough ambient that nothing is a silhouette. SceneKit's deferred
        // shadow map produced isolated dark blobs on the empty near court, so
        // the procedural rings and shoes provide the contact cue instead.
        let key = SCNLight()
        key.type = .directional
        key.color = UIColor(white: 1.0, alpha: 1.0)
        key.intensity = 900
        key.castsShadow = false
        let keyNode = SCNNode()
        keyNode.light = key
        keyNode.position = CourtCamera.scenePoint(x: 15, y: 40, height: 46)
        keyNode.eulerAngles = SCNVector3(-1.22, 0.22, 0)
        root.addChildNode(keyNode)

        let fill = SCNLight()
        fill.type = .ambient
        fill.intensity = 640
        fill.color = UIColor(red: 0.74, green: 0.82, blue: 0.88, alpha: 1)
        let fillNode = SCNNode()
        fillNode.light = fill
        root.addChildNode(fillNode)

        // A second, shadowless light from behind the viewer. Without it the far
        // players are lit only from above and read as two grey posts.
        let rim = SCNLight()
        rim.type = .directional
        rim.intensity = 380
        rim.castsShadow = false
        rim.color = UIColor(red: 0.86, green: 0.92, blue: 1.0, alpha: 1)
        let rimNode = SCNNode()
        rimNode.light = rim
        rimNode.eulerAngles = SCNVector3(-0.42, 0, 0)
        root.addChildNode(rimNode)
    }

    // MARK: - Surface

    private static func addGround(to root: SCNNode) {
        // The apron runs well past the court so the horizon is ground rather
        // than a hard edge into the background colour.
        let apron = box(width: 130, height: 0.4, length: 190, color: Theme.Surface.apron)
        apron.position = CourtCamera.scenePoint(x: CourtGeometry.centerX, y: 22, height: -0.22)
        root.addChildNode(apron)

        let play = box(
            width: CourtGeometry.width, height: 0.08, length: CourtGeometry.length,
            color: Theme.Surface.play
        )
        play.position = CourtCamera.scenePoint(x: CourtGeometry.centerX, y: 22, height: -0.02)
        root.addChildNode(play)

        // Both non-volley zones, painted the clay colour they carry on a real
        // court so the kitchen reads as a different place from across the net.
        for centerY in [CourtGeometry.netY - CourtGeometry.kitchenDepth / 2,
                        CourtGeometry.netY + CourtGeometry.kitchenDepth / 2] {
            let kitchen = box(
                width: CourtGeometry.width, height: 0.03,
                length: CourtGeometry.kitchenDepth, color: Theme.Surface.kitchen
            )
            kitchen.position = CourtCamera.scenePoint(
                x: CourtGeometry.centerX, y: centerY, height: 0.025
            )
            root.addChildNode(kitchen)
        }
    }

    private static func addLines(to root: SCNNode) {
        let paint = 0.17

        func line(x: Double, y: Double, width: Double, length: Double) {
            let node = box(width: width, height: 0.02, length: length, color: Theme.Surface.line)
            node.position = CourtCamera.scenePoint(x: x, y: y, height: 0.05)
            root.addChildNode(node)
        }

        // Baselines and sidelines.
        line(x: CourtGeometry.centerX, y: paint / 2, width: CourtGeometry.width, length: paint)
        line(x: CourtGeometry.centerX, y: CourtGeometry.length - paint / 2,
             width: CourtGeometry.width, length: paint)
        for x in [paint / 2, CourtGeometry.width - paint / 2] {
            line(x: x, y: CourtGeometry.netY, width: paint, length: CourtGeometry.length)
        }
        // Both kitchen lines, the ones the rulebook actually draws.
        for y in [CourtGeometry.ourKitchenLine, CourtGeometry.theirKitchenLine] {
            line(x: CourtGeometry.centerX, y: y, width: CourtGeometry.width, length: paint)
        }
        // Center lines stop at the kitchen on both sides.
        line(x: CourtGeometry.centerX, y: CourtGeometry.ourKitchenLine / 2,
             width: paint, length: CourtGeometry.ourKitchenLine)
        line(
            x: CourtGeometry.centerX,
            y: (CourtGeometry.theirKitchenLine + CourtGeometry.length) / 2,
            width: paint, length: CourtGeometry.length - CourtGeometry.theirKitchenLine
        )
    }

    /// The net, built as an actual mesh of cords rather than as a panel.
    ///
    /// Two attempts at a transparent panel both rendered as a solid black wall
    /// across the middle of the frame, hiding the opponents entirely, and each
    /// time the fix looked like it should have worked (alpha, blend mode, depth
    /// writes, rendering order). A net is holes held together by string, so it
    /// is drawn as holes held together by string: roughly forty thin boxes,
    /// which costs nothing and physically cannot occlude the far court.
    ///
    /// This matters more than it sounds. The net is the app's only reference
    /// for "net height", and every attackable-ball judgement in the product is
    /// a comparison against its tape.
    private static func addNet(to root: SCNNode) {
        let net = SCNNode()
        net.name = "net"
        let cord = 0.016

        // Verticals, one per foot across.
        var x = 0.0
        while x <= CourtGeometry.width + 0.001 {
            let strand = box(width: cord, height: netHeight, length: cord,
                             color: Theme.Surface.netMesh)
            strand.geometry?.firstMaterial = cordMaterial()
            strand.position = CourtCamera.scenePoint(
                x: x, y: CourtGeometry.netY, height: netHeight / 2
            )
            net.addChildNode(strand)
            x += 2.0
        }

        // Horizontals, every foot. Four was denser than a real net and,
        // at the distance the opponents stand, the strands closed up into a
        // near-solid dark grid across their legs: the mesh that exists so it
        // cannot occlude was occluding.
        var h = 0.0
        while h < netHeight - 0.05 {
            let strand = box(width: CourtGeometry.width, height: cord, length: cord,
                             color: Theme.Surface.netMesh)
            strand.geometry?.firstMaterial = cordMaterial()
            strand.position = CourtCamera.scenePoint(
                x: CourtGeometry.centerX, y: CourtGeometry.netY, height: h
            )
            net.addChildNode(strand)
            h += 1.0
        }
        root.addChildNode(net)

        // The tape. Bright and solid, because it is the reference edge.
        // (Cord material is below, in Primitives.)
        let tape = box(width: CourtGeometry.width + 0.1, height: 0.17, length: 0.11,
                       color: Theme.Surface.netTape)
        tape.position = CourtCamera.scenePoint(
            x: CourtGeometry.centerX, y: CourtGeometry.netY, height: netHeight
        )
        root.addChildNode(tape)

        for x in [-0.2, CourtGeometry.width + 0.2] {
            let post = SCNNode(geometry: SCNCylinder(radius: 0.11, height: CGFloat(postHeight)))
            post.geometry?.firstMaterial = material(Theme.Surface.netMesh)
            post.position = CourtCamera.scenePoint(
                x: x, y: CourtGeometry.netY, height: postHeight / 2
            )
            root.addChildNode(post)
        }
    }

    /// Closer than this to the eye, a full body is more obstruction than
    /// information: a six foot player a few feet from a six foot camera is a
    /// wall across a quarter of the frame. Only the partner can be this close,
    /// so the scene keeps their exact floor marker and omits only their torso.
    ///
    /// `CourtPOVView` reads the same constant so the P label follows either the
    /// player's head or the non-occluding floor marker.
    /// Raised from 15 after the all-phase screenshot pass. The eye sits 8.5 ft
    /// behind your own feet, so a partner at the far edge of the near half can
    /// still be over twenty feet away and render as a foreground wall, covering
    /// an aim ring. Only a truly distant partner gets a full body.
    static let minimumFullBodyDistance: Double = 26

    // MARK: - People

    enum PlayerKind {
        case opponent, partner, you

        var shirt: Color {
            switch self {
            // Opponents wear the same kit as each other on purpose. Telling
            // them apart is the player's job and it is done by reading where
            // they stand, not by colour-coding the answer.
            case .opponent: return Color(red: 0.82, green: 0.90, blue: 0.92)
            // NOT the optic yellow of the ball. Your partner was painted in it
            // and, standing a few feet from the camera, became the largest and
            // brightest object on screen: a teammate you never have to look at,
            // outshouting the ball whose height is the actual question.
            case .partner, .you: return Color(red: 0.129, green: 0.435, blue: 0.522)
            }
        }

        var shorts: Color {
            switch self {
            case .opponent: return Color(red: 0.16, green: 0.19, blue: 0.24)
            case .partner, .you: return Color(red: 0.13, green: 0.22, blue: 0.20)
            }
        }

        var ring: Color {
            switch self {
            case .opponent: return Color(red: 0.98, green: 0.99, blue: 1.0)
            case .partner, .you: return Color(red: 0.353, green: 0.749, blue: 0.831)
            }
        }

        /// Which way they are facing. Yours is the only one with their back to
        /// the camera.
        var facesAway: Bool { self != .opponent }
    }

    /// The fence and the dark beyond it.
    ///
    /// Without this the top third of the frame is flat background colour, which
    /// reads as a rendering bug rather than as sky. A fence behind the far
    /// baseline also gives the far end of the court something to be measured
    /// against, so the opponents' depth is legible.
    private static func addSurround(to root: SCNNode) {
        // Low and grey-green rather than tall and black. The first version was
        // an eleven foot black wall that filled the middle of the frame and
        // read as a rendering fault; a fence is something you see the court
        // against, not something that replaces it.
        let fenceColor = Color(red: 0.129, green: 0.204, blue: 0.196)
        // Ten feet, which is what a real court fence is. Seven was chosen when
        // the camera was pitched hard down and anything taller filled the
        // frame; with the eye level the fence now tops out just under the HUD
        // and the band above it reads as evening sky rather than as a void.
        let fenceHeight = 10.0
        let back = box(width: 86, height: fenceHeight, length: 0.25, color: fenceColor)
        back.geometry?.firstMaterial?.transparency = 0.5
        back.position = CourtCamera.scenePoint(
            x: CourtGeometry.centerX, y: CourtGeometry.length + 14, height: fenceHeight / 2
        )
        root.addChildNode(back)

        for x in [-30.0, CourtGeometry.width + 30.0] {
            let side = box(width: 0.25, height: fenceHeight, length: 130, color: fenceColor)
            side.geometry?.firstMaterial?.transparency = 0.45
            side.position = CourtCamera.scenePoint(x: x, y: 20, height: fenceHeight / 2)
            root.addChildNode(side)
        }
    }

    /// A close partner still needs an exact stance on screen. Two shoes and a
    /// floor ring carry that information without placing a six-foot foreground
    /// body between the player and every target on the far court.
    static func footprint(at point: CourtPoint, kind: PlayerKind) -> SCNNode {
        let node = SCNNode()
        node.name = "footprint"

        let ring = SCNNode(geometry: SCNTorus(ringRadius: 0.64, pipeRadius: 0.04))
        ring.geometry?.firstMaterial = glowing(kind.ring, intensity: 0.34)
        ring.geometry?.firstMaterial?.transparency = 0.72
        ring.position = SCNVector3(0, 0.07, 0)
        node.addChildNode(ring)
        addShoes(to: node, color: kind.shorts)

        node.position = CourtCamera.scenePoint(point)
        return node
    }

    /// A player, built from primitives, plus the ring under their feet.
    ///
    /// The ring is not decoration and it is not a compromise. Depth is the one
    /// thing perspective makes harder to read than a plan view, and this app's
    /// entire question is where four people's FEET are: whether the left
    /// opponent has actually made the kitchen line or is still a stride short
    /// is the read. A bright disc on the paint puts that back, and it is what a
    /// coach points at anyway.
    static func player(at point: CourtPoint, kind: PlayerKind) -> SCNNode {
        let node = SCNNode()
        node.name = "player"

        let legs = SCNNode()
        for side in [-0.28, 0.28] {
            let leg = SCNNode(geometry: SCNCapsule(capRadius: 0.16, height: 1.56))
            leg.geometry?.firstMaterial = material(kind.shorts)
            leg.position = SCNVector3(Float(side), 0.86, 0)
            legs.addChildNode(leg)
        }
        node.addChildNode(legs)
        addShoes(to: node, color: kind.shorts)

        let shorts = SCNNode(geometry: SCNBox(
            width: 1.20, height: 0.52, length: 0.62, chamferRadius: 0.18
        ))
        shorts.geometry?.firstMaterial = material(kind.shorts)
        shorts.position = SCNVector3(0, 1.78, 0)
        node.addChildNode(shorts)

        let torso = SCNNode(geometry: SCNBox(
            width: 1.18, height: 1.72, length: 0.62, chamferRadius: 0.24
        ))
        torso.geometry?.firstMaterial = material(kind.shirt)
        torso.position = SCNVector3(0, 2.82, 0)
        node.addChildNode(torso)

        let neck = SCNNode(geometry: SCNCylinder(radius: 0.18, height: 0.34))
        neck.geometry?.firstMaterial = material(Color(red: 0.76, green: 0.62, blue: 0.51))
        neck.position = SCNVector3(0, 3.86, 0)
        node.addChildNode(neck)

        for side in [-1.0, 1.0] {
            let arm = SCNNode(geometry: SCNCapsule(capRadius: 0.14, height: 1.38))
            arm.geometry?.firstMaterial = material(kind.shirt)
            arm.position = SCNVector3(Float(side * 0.70), 2.88, 0.03)
            arm.eulerAngles.z = Float(side * 0.52)
            node.addChildNode(arm)
        }

        let head = SCNNode(geometry: SCNSphere(radius: 0.35))
        head.geometry?.firstMaterial = material(Color(red: 0.76, green: 0.62, blue: 0.51))
        head.position = SCNVector3(0, 4.34, 0)
        node.addChildNode(head)

        // Paddle, held up in a ready position. Small, but it is what makes the
        // silhouette read as a pickleball player rather than a bollard.
        let paddle = SCNNode(geometry: SCNBox(
            width: 0.66, height: 0.88, length: 0.07, chamferRadius: 0.15
        ))
        paddle.geometry?.firstMaterial = material(Color(red: 0.12, green: 0.14, blue: 0.17))
        paddle.position = SCNVector3(0.76, 2.52, 0.40)
        paddle.eulerAngles = SCNVector3(0, 0, -0.45)
        node.addChildNode(paddle)

        let ring = SCNNode(geometry: SCNTorus(ringRadius: 0.64, pipeRadius: 0.04))
        ring.geometry?.firstMaterial = glowing(kind.ring, intensity: 0.34)
        ring.geometry?.firstMaterial?.transparency = 0.72
        ring.position = SCNVector3(0, 0.07, 0)
        node.addChildNode(ring)

        node.position = CourtCamera.scenePoint(point)
        // Everyone faces the net; only yours has its back to the camera.
        node.eulerAngles = SCNVector3(0, kind.facesAway ? 0 : Float.pi, 0)
        return node
    }

    private static func addShoes(to node: SCNNode, color: Color) {
        for side in [-0.32, 0.32] {
            let shoe = SCNNode(geometry: SCNBox(
                width: 0.42, height: 0.14, length: 0.72, chamferRadius: 0.08
            ))
            shoe.geometry?.firstMaterial = material(color)
            shoe.position = SCNVector3(Float(side), 0.10, -0.13)
            node.addChildNode(shoe)
        }
    }

    /// The live ball, with a local height reference that makes the read legible.
    ///
    /// A sphere hanging in perspective carries almost no height information on
    /// its own: high and near looks identical to low and far. The short guide
    /// and net-height bar beside it turn that ambiguity into a local comparison.
    static func ball(at point: CourtPoint, height: Double) -> SCNNode {
        let node = SCNNode()
        node.name = "ball"

        // The tape, brought to the ball.
        //
        // This is the single most important object in the scene and the first
        // build did not have it. The app's whole claim is that "can I attack
        // this" becomes something you SEE, and it was not: the net is twenty
        // feet away and the ball is at your shoulder, so comparing their
        // heights across that much perspective is guesswork, and players were
        // back to reading the caption. A thin hoop at exactly net height,
        // around the ball's own drop line, makes the comparison local: ball
        // above the hoop is a ball you can hit down on, and no text says so.
        //
        // It is not a hint. Net height is a fact about the court that a player
        // standing on one can see in their peripheral vision for free, and
        // taking it away is what made the render dishonest rather than hard.
        // A bar on the drop line, at exactly net height.
        //
        // Two versions of this were wrong before it. A torus of net-tape radius
        // projected as a four-hundred-pixel ellipse lying across the near
        // court; shrinking it to a disc still read as a white puck on the
        // paint, because a disc seen from above is a disc. A BAR across the
        // ball's own drop line reads as one thing only: a height. Ball above
        // the bar is a ball you can hit down on, and no caption says so.
        //
        // It is not a hint. Net height is a fact a player standing on a court
        // has in their peripheral vision for free, and taking it away is what
        // made the render dishonest rather than hard.
        // Drawn twice: a dark backing bar and a bright one on top of it. A
        // single white bar disappears against the white kitchen line and the
        // white court paint, which is exactly where it lands on the phases
        // where the ball is low, and a mark you cannot find is worse than no
        // mark because the player assumes they have read it.
        let shadowBar = box(width: 0.76, height: 0.08, length: 0.15, color: Color(white: 0.04))
        shadowBar.geometry?.firstMaterial?.lightingModel = .constant
        shadowBar.geometry?.firstMaterial?.transparency = 0.55
        shadowBar.position = SCNVector3(0, Float(netHeight), 0)
        node.addChildNode(shadowBar)

        let tape = box(width: 0.66, height: 0.035, length: 0.12, color: Theme.Surface.netTape)
        tape.geometry?.firstMaterial = glowing(Theme.Surface.netTape, intensity: 0.9)
        tape.position = SCNVector3(0, Float(netHeight), 0)
        node.addChildNode(tape)

        for side in [-0.32, 0.32] {
            let cap = SCNNode(geometry: SCNBox(
                width: 0.035, height: 0.13, length: 0.12, chamferRadius: 0.01
            ))
            cap.geometry?.firstMaterial = glowing(Theme.Surface.netTape, intensity: 0.9)
            cap.position = SCNVector3(Float(side), Float(netHeight), 0)
            node.addChildNode(cap)
        }

        // A pickleball is about 2.9 inches across. The render is enlarged by a
        // quarter for legibility, not doubled into the beach ball the old
        // 0.22-foot radius produced in close return positions.
        let sphere = SCNNode(geometry: SCNSphere(radius: 0.15))
        sphere.geometry?.firstMaterial = glowing(Theme.Surface.ball, intensity: 1.0)
        sphere.position = SCNVector3(0, Float(height), 0)
        node.addChildNode(sphere)

        // A short dashed comparison guide joins the ball to the net-height
        // tick. Extending it to the floor made close contacts look like a
        // yellow laser planted through half the screen.
        let guideBottom = min(height, netHeight) - 0.20
        let guideTop = max(height, netHeight) + 0.20
        var dashStart = max(0.08, guideBottom)
        while dashStart < guideTop - 0.04 {
            let dashHeight = min(0.16, guideTop - dashStart)
            let dash = SCNNode(geometry: SCNCylinder(radius: 0.011, height: dashHeight))
            dash.geometry?.firstMaterial = glowing(Theme.Surface.ball, intensity: 0.18)
            dash.geometry?.firstMaterial?.transparency = 0.42
            dash.position = SCNVector3(0, Float(dashStart + dashHeight / 2), 0)
            node.addChildNode(dash)
            dashStart += 0.27
        }

        node.position = CourtCamera.scenePoint(point)
        return node
    }

    /// One of the four places you can hit it: a ring on the paint.
    static func aimTarget(at point: CourtPoint, color: Color, emphasised: Bool) -> SCNNode {
        let node = SCNNode()
        node.name = "aim"

        let ring = SCNNode(geometry: SCNTorus(
            ringRadius: emphasised ? 0.94 : 0.82, pipeRadius: emphasised ? 0.075 : 0.055
        ))
        ring.geometry?.firstMaterial = glowing(color, intensity: emphasised ? 0.95 : 0.42)
        ring.position = SCNVector3(0, 0.09, 0)
        node.addChildNode(ring)

        let disc = SCNNode(geometry: SCNCylinder(
            radius: emphasised ? 0.90 : 0.78, height: 0.02
        ))
        disc.geometry?.firstMaterial = glowing(color, intensity: emphasised ? 0.10 : 0.035)
        disc.geometry?.firstMaterial?.transparency = emphasised ? 0.82 : 0.94
        disc.position = SCNVector3(0, 0.08, 0)
        node.addChildNode(disc)

        node.position = CourtCamera.scenePoint(point)
        return node
    }

    // MARK: - Primitives

    private static func box(
        width: Double, height: Double, length: Double, color: Color
    ) -> SCNNode {
        let geometry = SCNBox(
            width: CGFloat(width), height: CGFloat(height),
            length: CGFloat(length), chamferRadius: 0
        )
        geometry.firstMaterial = material(color)
        return SCNNode(geometry: geometry)
    }

    /// One cord of the net.
    ///
    /// Unlit and half transparent, and it took three passes to get here. Lit
    /// with the same physically-based material as everything else, a cord thin
    /// enough to be a cord renders almost black whatever colour it is given,
    /// and forty of them close into a grid that hides the opponents' legs. It
    /// also does not write depth, so nothing behind the net can be occluded by
    /// it even where the strands cross.
    private static func cordMaterial() -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .constant
        m.diffuse.contents = uiColor(Theme.Surface.netMesh)
        m.transparency = 0.28
        m.writesToDepthBuffer = false
        m.isDoubleSided = true
        return m
    }

    private static func material(_ color: Color) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        m.diffuse.contents = uiColor(color)
        m.roughness.contents = 0.85
        m.metalness.contents = 0.0
        return m
    }

    private static func glowing(_ color: Color, intensity: Double) -> SCNMaterial {
        let m = material(color)
        m.emission.contents = uiColor(color).withAlphaComponent(CGFloat(intensity))
        return m
    }

    private static func uiColor(_ color: Color) -> UIColor { UIColor(color) }
}

private extension UIColor {
    /// Darkens toward black, for the sky behind the court.
    func darker(by amount: CGFloat) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        let k = max(0, 1 - amount)
        return UIColor(red: r * k, green: g * k, blue: b * k, alpha: a)
    }
}
