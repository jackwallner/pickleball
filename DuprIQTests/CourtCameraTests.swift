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

    private func everyPosition(_ body: (RallyPosition) -> Void) {
        everyQuestion { body($0.position) }
    }

    private func isOnScreen(_ p: CGPoint?, in size: CGSize, margin: CGFloat = 0) -> Bool {
        guard let p else { return false }
        return p.x >= -margin && p.x <= size.width + margin
            && p.y >= -margin && p.y <= size.height + margin
    }

    /// The ball is the subject of the question. If it is not on screen the
    /// question cannot be answered, and the player is being asked to judge a
    /// height they cannot see.
    func testTheBallIsAlwaysInFrame() {
        for size in [phone, pad] {
            everyQuestion { question in
                let position = question.position
                let camera = CourtCamera.viewing(question, aspect: Double(size.width / size.height))
                let screen = camera.project(
                    position.contact,
                    height: CourtScene.ballHeight(position.ballHeight),
                    in: size
                )
                XCTAssertTrue(
                    isOnScreen(screen, in: size),
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
                let camera = CourtCamera.viewing(question, aspect: Double(size.width / size.height))
                for side in OpponentSide.allCases {
                    let point = position.opponent(side)
                    let feet = camera.project(point, in: size)
                    XCTAssertTrue(
                        isOnScreen(feet, in: size),
                        "\(position.id): \(side.rawValue) opponent's feet off frame in \(size)"
                    )
                    let head = camera.project(point, height: 5.4, in: size)
                    XCTAssertTrue(
                        isOnScreen(head, in: size, margin: 24),
                        "\(position.id): \(side.rawValue) opponent's head off frame in \(size)"
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
                    let camera = CourtCamera.viewing(
                        question, aspect: Double(size.width / size.height)
                    )
                    let points = ShotAiming.aimPoints(
                        for: question.options, in: question.position,
                        answer: question.answer,
                        answerTarget: question.verdict.targetOpponent
                    )
                    for (shot, point) in zip(question.options, points) {
                        // The whole ring, not its centre. A ring is nearly two
                        // feet across, and framing only the point a shot lands
                        // on put the outermost option on screen as an arc
                        // sliced off by the edge.
                        for dx in [-1.6, 0.0, 1.6] {
                            let edge = CourtPoint(x: point.x + dx, y: point.y)
                            XCTAssertTrue(
                                isOnScreen(camera.project(edge, height: 0.1, in: size), in: size),
                                "\(question.position.id): \(shot.id) ring is off frame in \(size)"
                            )
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
            let camera = CourtCamera.viewing(question)
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
            let camera = CourtCamera.viewing(question)
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
            let camera = CourtCamera.viewing(question)
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
                let camera = CourtCamera.viewing(
                    question, aspect: Double(size.width / size.height)
                )
                let screen = camera.project(
                    question.position.contact, height: CourtScene.netHeight, in: size
                )
                XCTAssertTrue(
                    isOnScreen(screen, in: size),
                    "\(question.position.id): the tape reference is off frame in \(size)"
                )
            }
        }
    }

    /// The subject is not pinned to an edge of the frame.
    ///
    /// This is the failure a screenshot caught and every other test in this
    /// file passed through: the camera contained everything it was asked to
    /// contain, and then tilted so hard that both opponents and all four rings
    /// landed in the top fifth of the screen with nothing under them. The
    /// contract is composition, not just containment, so it is asserted.
    func testTheOpponentsAreNotJammedAgainstAnEdgeOfTheFrame() {
        everyQuestion { question in
            let camera = CourtCamera.viewing(question)
            for side in OpponentSide.allCases {
                guard let feet = camera.project(question.position.opponent(side), in: phone) else {
                    return XCTFail("\(question.position.id): \(side.rawValue) did not project")
                }
                XCTAssertGreaterThan(
                    feet.y, phone.height * 0.16,
                    "\(question.position.id): \(side.rawValue) is jammed against the top"
                )
                XCTAssertLessThan(
                    feet.y, phone.height * 0.72,
                    "\(question.position.id): \(side.rawValue) is jammed against the bottom"
                )
            }
        }
    }

    /// There is room under every ring for the caption that names it.
    ///
    /// `AimLabelLayout` puts captions in the near court below their rings, and
    /// it can only do that if the rings are not already sitting on the band the
    /// verdict card will cover.
    func testEveryRingLeavesRoomForItsCaption() {
        everyQuestion { question in
            let camera = CourtCamera.viewing(question)
            let points = ShotAiming.aimPoints(
                for: question.options, in: question.position,
                answer: question.answer,
                answerTarget: question.verdict.targetOpponent
            )
            let floor = phone.height - CourtPOVView.verdictBandHeight(in: phone)
            for (shot, point) in zip(question.options, points) {
                guard let screen = camera.project(point, height: 0.1, in: phone) else {
                    return XCTFail("\(question.position.id): \(shot.id) did not project")
                }
                XCTAssertLessThan(
                    screen.y, floor,
                    "\(question.position.id): \(shot.id) sits in the verdict card's band"
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
