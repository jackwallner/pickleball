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

    private func everyPosition(_ body: (RallyPosition) -> Void) {
        for phase in RallyPhase.allCases {
            for seed in 0..<60 as Range<UInt64> {
                body(PositionGenerator.question(phase: phase, seed: seed &* 7919 &+ 3).position)
            }
        }
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
            everyPosition { position in
                let camera = CourtCamera.viewing(position)
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
            everyPosition { position in
                let camera = CourtCamera.viewing(position)
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
                    let camera = CourtCamera.viewing(question.position)
                    let points = ShotAiming.aimPoints(
                        for: question.options, in: question.position,
                        answer: question.answer,
                        answerTarget: question.verdict.targetOpponent
                    )
                    for (shot, point) in zip(question.options, points) {
                        XCTAssertTrue(
                            isOnScreen(camera.project(point, height: 0.1, in: size), in: size),
                            "\(question.position.id): \(shot.id) ring is off frame in \(size)"
                        )
                    }
                }
            }
        }
    }

    /// The eye is behind the ball, never level with it or past it. `you` and
    /// `contact` are generated independently, so without this a legal position
    /// can put the ball inside the lens.
    func testTheEyeIsAlwaysBehindTheBall() {
        everyPosition { position in
            let camera = CourtCamera.viewing(position)
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
        everyPosition { position in
            let camera = CourtCamera.viewing(position)
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
        everyPosition { position in
            let camera = CourtCamera.viewing(position)
            let depth = CourtGeometry.theirKitchenLine
            guard
                let left = camera.project(CourtPoint(x: 3, y: depth), in: phone),
                let right = camera.project(CourtPoint(x: 17, y: depth), in: phone)
            else { return XCTFail("\(position.id): sideline off frame") }
            XCTAssertLessThan(left.x, right.x, "\(position.id): the court is mirrored")
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
