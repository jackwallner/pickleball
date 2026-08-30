import XCTest
@testable import DuprIQ

/// The framing contract.
///
/// A first-person view can be wrong in a way no other test notices: everything
/// computes, the scene renders, and the one object the question is about is
/// simply not in the frame. That happened twice while this was being built, and
/// both times it took a screenshot to notice. The camera is pure maths, so the
/// things that have to be on screen can just be asserted.
final class CourtCameraTests: XCTestCase {

    /// A phone in portrait. The tightest case: the frame is twice as tall as it
    /// is wide, so the horizontal angle is the scarce one.
    private let phone = CGSize(width: 402, height: 874)
    /// An iPad in landscape, where the vertical angle becomes the scarce one.
    private let pad = CGSize(width: 1180, height: 820)

    /// Every assertion below runs against a whole QUESTION, not a bare
    /// position, because the camera is fitted to the four rings this question
    /// actually draws. Fitting to a synthetic region of every place a ring
    /// could ever land is what pinned the subject into a band across the top of
    /// the screen in the build before this one, and a test that framed the same
    /// synthetic region would have gone on passing.
    private func everyQuestion(_ body: (DrillQuestion) -> Void) {
        for phase in RallyPhase.allCases {
            for seed in 0..<60 as Range<UInt64> {
                body(PositionGenerator.question(phase: phase, seed: seed &* 7919 &+ 3))
            }
        }
    }

    /// The camera exactly as `CourtPOVView` builds it on the drill screen.
    ///
    /// Fitting without the chrome bands and then asserting containment against
    /// the whole frame is the test that passed while the HUD covered the far
    /// opponent and the option panel covered two of the rings. What has to be
    /// visible is what is visible BETWEEN them.
    private func drillCamera(_ question: DrillQuestion, in size: CGSize) -> CourtCamera {
        let chrome = CourtPOVView.Chrome.fullBleedDrill
        return CourtCamera.viewing(
            question,
            aspect: Double(size.width / size.height),
            topFraction: Double(chrome.topInset(in: size) / size.height),
            bottomFraction: Double(chrome.optionBand(in: size) / size.height)
        )
    }

    /// The strip of the frame nothing is drawn over.
    private func band(in size: CGSize) -> (top: CGFloat, bottom: CGFloat) {
        let chrome = CourtPOVView.Chrome.fullBleedDrill
        return (chrome.topInset(in: size), size.height - chrome.optionBand(in: size))
    }

    private func isOnScreen(_ p: CGPoint?, in size: CGSize, margin: CGFloat = 0) -> Bool {
        guard let p else { return false }
        return p.x >= -margin && p.x <= size.width + margin
            && p.y >= -margin && p.y <= size.height + margin
    }

    /// On screen AND not underneath the HUD or the option panel.
    private func isInBand(_ p: CGPoint?, in size: CGSize, margin: CGFloat = 0) -> Bool {
        guard let p, isOnScreen(p, in: size, margin: margin) else { return false }
        let limits = band(in: size)
        return p.y >= limits.top - margin && p.y <= limits.bottom + margin
    }

    private func ringSamples(
        around centre: CourtPoint, radius: Double, height: Double
    ) -> [(point: CourtPoint, height: Double)] {
        (0..<16).map { sample in
            let angle = Double(sample) * 2 * .pi / 16
            return (
                point: CourtPoint(
                    x: centre.x + cos(angle) * radius,
                    y: centre.y + sin(angle) * radius
                ),
                height: height
            )
        }
    }

    /// The ball is the subject of the question. If it is not on screen the
    /// question cannot be answered, and the player is being asked to judge a
    /// height they cannot see.
    func testTheBallIsAlwaysInFrame() {
        for size in [phone, pad] {
            everyQuestion { question in
                let position = question.position
                let camera = drillCamera(question, in: size)
                let screen = camera.project(
                    position.contact,
                    height: CourtScene.ballHeight(position.ballHeight),
                    in: size
                )
                XCTAssertTrue(
                    isInBand(screen, in: size),
                    "\(position.id): the ball projected to \(String(describing: screen)) in \(size)"
                )
            }
        }
    }

    /// Both opponents, because how far apart they are standing is a read the
    /// advisor branches on. One of them off the edge of the frame turns that
    /// read into a guess.
    func testBothOpponentsAreAlwaysInFrame() {
        for size in [phone, pad] {
            everyQuestion { question in
                let position = question.position
                let camera = drillCamera(question, in: size)
                for side in OpponentSide.allCases {
                    let point = position.opponent(side)
                    let feet = camera.project(point, in: size)
                    XCTAssertTrue(
                        isInBand(feet, in: size),
                        "\(position.id): \(side.rawValue) opponent's feet are behind the chrome in \(size)"
                    )
                    let head = camera.project(point, height: 5.4, in: size)
                    XCTAssertTrue(
                        isInBand(head, in: size, margin: 24),
                        "\(position.id): \(side.rawValue) opponent's head is behind the chrome in \(size)"
                    )
                }
            }
        }
    }

    /// Every place you could hit it has to be somewhere you can see. A ring
    /// that projects off the frame is an option with no target behind it.
    func testEveryAimPointIsInFrame() {
        for size in [phone, pad] {
            for phase in RallyPhase.allCases {
                for seed in 0..<30 as Range<UInt64> {
                    let question = PositionGenerator.question(phase: phase, seed: seed &* 31 &+ 9)
                    let camera = drillCamera(question, in: size)
                    let points = ShotAiming.aimPoints(
                        for: question.options, in: question.position,
                        answer: question.answer,
                        answerTarget: question.verdict.targetOpponent
                    )
                    for (shot, point) in zip(question.options, points) {
                        // The whole rendered torus, not its centre. The
                        // emphasized ring is over three feet across, and its
                        // pipe has vertical thickness, so four horizontal
                        // points at one height do not prove containment.
                        for height in [-0.06, 0.24] {
                            for edge in ringSamples(around: point, radius: 1.8, height: height) {
                                XCTAssertTrue(
                                    isInBand(camera.project(edge.point, height: edge.height, in: size), in: size),
                                    "\(question.position.id): \(shot.id) ring is behind the chrome in \(size)"
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    /// The eye is behind the ball, never level with it or past it. The contact
    /// is a reach from your stance now, so this is a step back rather than the
    /// rescue it used to be, but a ball inside the lens is unrecoverable and
    /// costs one assertion to rule out.
    func testTheEyeIsAlwaysBehindTheBall() {
        everyQuestion { question in
            let position = question.position
            let camera = drillCamera(question, in: phone)
            XCTAssertLessThan(
                camera.eye.y, position.contact.y,
                "\(position.id): the eye is level with or past the contact"
            )
            XCTAssertGreaterThan(camera.distance(to: position.contact), 3)
        }
    }

    /// The far court is up the screen and the near court is down it. If this
    /// ever inverts, the projection's sign has flipped and every label lands on
    /// the wrong side of the net while the scene still renders correctly.
    func testDepthRunsUpTheScreen() {
        everyQuestion { question in
            let position = question.position
            let camera = drillCamera(question, in: phone)
            let near = camera.project(
                CourtPoint(x: CourtGeometry.centerX, y: CourtGeometry.ourKitchenLine),
                in: phone
            )
            let far = camera.project(
                CourtPoint(x: CourtGeometry.centerX, y: CourtGeometry.theirKitchenLine),
                in: phone
            )
            guard let near, let far else { return XCTFail("\(position.id): kitchen off frame") }
            XCTAssertLessThan(far.y, near.y, "\(position.id): their end is below ours")
        }
    }

    /// Left on the court is left on the screen. This is the projection half of
    /// the mirror property the advisor promises: if it inverted, every answer
    /// naming "the left opponent" would point at the marker on the right.
    func testLeftOnTheCourtIsLeftOnTheScreen() {
        everyQuestion { question in
            let position = question.position
            let camera = drillCamera(question, in: phone)
            let depth = CourtGeometry.theirKitchenLine
            guard
                let left = camera.project(CourtPoint(x: 3, y: depth), in: phone),
                let right = camera.project(CourtPoint(x: 17, y: depth), in: phone)
            else { return XCTFail("\(position.id): sideline off frame") }
            XCTAssertLessThan(left.x, right.x, "\(position.id): the court is mirrored")
        }
    }

    /// The net-height reference beside the ball has to be in frame too.
    ///
    /// The comparison between the ball and that hoop IS the question. Half of
    /// it on screen is no more useful than none of it, and nothing else in the
    /// suite would notice a hoop that projected off the bottom edge.
    func testTheNetHeightReferenceIsInFrameBesideTheBall() {
        for size in [phone, pad] {
            everyQuestion { question in
                let camera = drillCamera(question, in: size)
                let screen = camera.project(
                    question.position.contact, height: CourtScene.netHeight, in: size
                )
                XCTAssertTrue(
                    isInBand(screen, in: size),
                    "\(question.position.id): the tape reference is behind the chrome in \(size)"
                )
            }
        }
    }

    /// The subject is not pinned to an edge of the visible band.
    ///
    /// This is the failure a screenshot caught and every other test in this
    /// file passed through: the camera contained everything it was asked to
    /// contain, and then tilted so hard that both opponents and all four rings
    /// landed in the top fifth of the screen with nothing under them. The
    /// contract is composition, not just containment, so it is asserted.
    func testTheOpponentsAreNotJammedAgainstAnEdgeOfTheBand() {
        let limits = band(in: phone)
        let height = limits.bottom - limits.top
        everyQuestion { question in
            let camera = drillCamera(question, in: phone)
            for side in OpponentSide.allCases {
                guard let feet = camera.project(question.position.opponent(side), in: phone) else {
                    return XCTFail("\(question.position.id): \(side.rawValue) did not project")
                }
                XCTAssertGreaterThan(
                    feet.y, limits.top + height * 0.06,
                    "\(question.position.id): \(side.rawValue) is jammed under the HUD"
                )
                XCTAssertLessThan(
                    feet.y, limits.top + height * 0.88,
                    "\(question.position.id): \(side.rawValue) is jammed against the panel"
                )
            }
        }
    }

    /// The camera fits the rendered outlines, not only the centre points used
    /// by the content model. This keeps the opponents' floor rings, your stance
    /// ring, the ball and its height bar from being clipped at the edge.
    func testRenderedSceneExtentsAreInFrame() {
        let opponentRingRadius = 1.125
        let stanceRingRadius = 0.935
        let ballRadius = 0.22
        for size in [phone, pad] {
            everyQuestion { question in
                let position = question.position
                let camera = drillCamera(question, in: size)

                func assertVisible(
                    _ point: CourtPoint, height: Double, _ label: String
                ) {
                    XCTAssertTrue(
                        isInBand(camera.project(point, height: height, in: size), in: size),
                        "\(position.id): \(label) is behind the chrome in \(size)"
                    )
                }

                for side in OpponentSide.allCases {
                    for height in [-0.005, 0.145] {
                        for sample in ringSamples(
                            around: position.opponent(side),
                            radius: opponentRingRadius,
                            height: height
                        ) {
                            assertVisible(sample.point, height: sample.height, "\(side.rawValue) ring")
                        }
                    }
                }

                for height in [0.035, 0.105] {
                    for sample in ringSamples(
                        around: position.you, radius: stanceRingRadius, height: height
                    ) {
                        assertVisible(sample.point, height: sample.height, "stance ring")
                    }
                }

                let contactHeight = CourtScene.ballHeight(position.ballHeight)
                for xOffset in [-ballRadius, ballRadius] {
                    for yOffset in [-ballRadius, ballRadius] {
                        for heightOffset in [-ballRadius, ballRadius] {
                            assertVisible(
                                CourtPoint(
                                    x: position.contact.x + xOffset,
                                    y: position.contact.y + yOffset
                                ),
                                height: contactHeight + heightOffset,
                                "ball"
                            )
                        }
                    }
                }

                for xOffset in [-0.57, 0.57] {
                    for yOffset in [-0.095, 0.095] {
                        for heightOffset in [-0.12, 0.12] {
                            assertVisible(
                                CourtPoint(
                                    x: position.contact.x + xOffset,
                                    y: position.contact.y + yOffset
                                ),
                                height: CourtScene.netHeight + heightOffset,
                                "net-height bar"
                            )
                        }
                    }
                }

            }
        }
    }

    /// The question fills the part of the screen it was given.
    ///
    /// Containment alone is not the contract and never was. Every camera test
    /// in this file passed on the build whose audit screenshots showed all four
    /// rings, both opponents and the ball inside a two hundred point strip with
    /// half the display below it showing empty near court: everything was in
    /// frame, and the frame was mostly nothing. The band exists so that space
    /// is spent on the option panel instead, and this asserts it actually is.
    ///
    /// Measured from the highest thing that matters (an opponent's head) to the
    /// lowest (your own feet), which is the full vertical extent of what the
    /// camera was asked to contain.
    ///
    /// It will never be 100%. A portrait phone is twice as tall as it is wide,
    /// and the four rings routinely span most of the far court's width, so the
    /// angle is often set horizontally and the surplus has to go somewhere
    /// vertical. The threshold is what the geometry actually allows, and it is
    /// here to catch the surplus growing, not to demand a perfect fit.
    func testTheSubjectFillsTheVisibleBand() {
        for size in [phone, pad] {
            let limits = band(in: size)
            let height = limits.bottom - limits.top
            everyQuestion { question in
                let position = question.position
                let camera = drillCamera(question, in: size)
                var top = CGFloat.greatestFiniteMagnitude
                var bottom = -CGFloat.greatestFiniteMagnitude
                var seen: [CGPoint] = []
                for side in OpponentSide.allCases {
                    if let head = camera.project(position.opponent(side), height: 5.4, in: size) {
                        seen.append(head)
                    }
                }
                if let shadow = camera.project(position.contact, in: size) { seen.append(shadow) }
                // Your own feet, which the fit frames on purpose so the stance
                // ring is visible, and which are the lowest thing on the court
                // that matters. Leaving them out measures a subject the camera
                // was never asked to fit.
                if let feet = camera.project(position.you, in: size) { seen.append(feet) }
                for point in seen {
                    top = min(top, point.y)
                    bottom = max(bottom, point.y)
                }
                guard bottom > top else { return XCTFail("\(position.id): nothing projected") }
                XCTAssertGreaterThan(
                    (bottom - top) / height, 0.55,
                    "\(position.id): the subject uses \(Int((bottom - top) / height * 100))% of the band in \(size)"
                )
            }
        }
    }

    /// Behind the eye means no point, not a point folded back into the frame.
    func testPointsBehindTheEyeDoNotProject() {
        let position = PositionGenerator.question(phase: .dinkRally, seed: 77).position
        let camera = CourtCamera.viewing(position)
        let behind = CourtPoint(x: camera.eye.x, y: camera.eye.y - 12)
        XCTAssertNil(camera.project(behind, height: 3, in: phone))
    }
}
