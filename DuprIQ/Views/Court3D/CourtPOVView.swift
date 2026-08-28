import SceneKit
import SwiftUI

/// The rally, from where you are standing, with the four places you could hit
/// it drawn on the court in front of you.
///
/// This replaces "read a plan-view diagram, then pick a sentence off a list"
/// with "look at what is in front of you and aim". The grading underneath is
/// untouched: a tap still resolves to an index into the question's options, so
/// `ShotAdvisor` and `PositionGenerator` and every test that pins them keep
/// working exactly as before. What changed is that the decisive facts, how high
/// the ball is and where their feet are, are now things you SEE rather than
/// things the app prints above the options.
///
/// The caption on each target says the shot SHAPE only ("Drop", "Drive"). The
/// place is not written down anywhere, because the place is the ring, and
/// asking someone to read "cross-court kitchen" off a pill while a ring sits on
/// the cross-court kitchen would be handing back the answer the render is
/// asking them to find.
struct CourtPOVView: View {

    enum Phase: Equatable {
        case deciding
        /// The picked option and the correct one. Both are needed: the ring the
        /// player chose has to stay visible next to the one they should have.
        case graded(picked: Int, answer: Int)

        var isGraded: Bool { if case .graded = self { return true }; return false }
    }

    let position: RallyPosition
    let options: [Shot]
    let aimPoints: [CourtPoint]
    let phase: Phase
    /// Nil while the ball is being graded, which is how the view is made
    /// read-only without `.disabled()` dimming the captions.
    var onPick: ((Int) -> Void)?

    private static let labelSize = CGSize(width: 118, height: 44)

    /// The camera is fitted to the frame it will actually be drawn in.
    ///
    /// Aspect ratio is an input to the fit, not a detail: the angle needed to
    /// contain the court's width depends entirely on how wide the frame is.
    /// The full-bleed drill screen is a portrait phone; the same view inside a
    /// session runner is a short wide box, and on iPad it is wider still.
    /// Fitting for one and rendering in another is how an opponent ends up off
    /// the edge in one place and not the other.
    private func camera(for size: CGSize) -> CourtCamera {
        CourtCamera.viewing(
            position,
            aspect: size.height > 0 ? Double(size.width / size.height) : CourtCamera.defaultAspect
        )
    }

    var body: some View {
        GeometryReader { geo in
            let camera = camera(for: geo.size)
            ZStack {
                CourtSceneView(
                    position: position,
                    camera: camera,
                    aimPoints: aimPoints,
                    colors: options.indices.map { ringColor(for: $0) },
                    emphasised: emphasisedIndex
                )
                .accessibilityHidden(true)

                let placements = layout(with: camera, in: geo.size)

                leaderLines(placements)
                playerLabels(with: camera, in: geo.size)
                aimButtons(placements)
            }
            .contentShape(Rectangle())
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(position.spokenDescription(
            highlight: phase.isGraded ? gradedTargetOpponent : nil
        ))
    }

    // MARK: - Layout

    private func layout(
        with camera: CourtCamera, in size: CGSize
    ) -> [AimLabelLayout.Placement] {
        AimLabelLayout.place(
            anchors: aimPoints.map { camera.project($0, height: 0.1, in: size) },
            labelSize: Self.labelSize,
            in: size
        )
    }

    /// A hairline from each caption back to the ring it names. Without it a
    /// caption that had to move to avoid a neighbour is just floating text.
    private func leaderLines(
        _ placements: [AimLabelLayout.Placement]
    ) -> some View {
        Canvas { context, _ in
            for placement in placements {
                var path = Path()
                path.move(to: placement.label)
                path.addLine(to: placement.anchor)
                context.stroke(
                    path,
                    with: .color(lineColor(for: placement.index)),
                    style: StrokeStyle(lineWidth: 1.5, dash: [3, 3])
                )
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Who is who. The scene deliberately dresses both opponents identically,
    /// so the letters are what let an explanation say "the left opponent" and
    /// have the player know which body it means.
    @ViewBuilder
    private func playerLabels(with camera: CourtCamera, in size: CGSize) -> some View {
        ForEach(labelledPlayers(camera), id: \.0) { entry in
            let (id, point, text) = entry
            // Just above the head the scene actually draws. Projecting at a
            // nominal 6 feet put the initial a body's length above a nearby
            // player, pointing at empty court.
            if let screen = camera.project(point, height: 5.3, in: size),
               isOnScreen(screen, in: size) {
                Text(text)
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(Theme.Surface.play)
                    .frame(width: 20, height: 20)
                    .background(.white.opacity(0.94), in: Circle())
                    .position(screen)
                    .accessibilityHidden(true)
                    .id(id)
            }
        }
    }

    private func labelledPlayers(_ camera: CourtCamera) -> [(String, CourtPoint, String)] {
        var entries: [(String, CourtPoint, String)] = [
            ("L", position.opponentLeft, "L"),
            ("R", position.opponentRight, "R"),
        ]
        // Only label a partner the scene drew. An initial floating over a body
        // that was culled for being too near the lens names nobody.
        if camera.distance(to: position.partner) > CourtScene.minimumDrawDistance {
            entries.append(("P", position.partner, "P"))
        }
        return entries
    }

    /// The four aim targets, as buttons sitting over their rings.
    @ViewBuilder
    private func aimButtons(_ placements: [AimLabelLayout.Placement]) -> some View {
        ForEach(placements, id: \.index) { placement in
            if let shot = options[safe: placement.index] {
                AimTargetLabel(shot: shot, state: state(for: placement.index))
                    .frame(width: Self.labelSize.width, height: Self.labelSize.height)
                    .position(placement.label)
                    .onTapGesture { onPick?(placement.index) }
                    .allowsHitTesting(onPick != nil)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel(shot.label)
                    .accessibilityHint("Aims \(shot.target.label)")
                    .accessibilityValue(accessibilityValue(for: placement.index))
                    .accessibilityIdentifier("shot-\(placement.index)")
            }
        }
    }

    private func state(for index: Int) -> AimTargetLabel.State {
        switch phase {
        case .deciding:
            return .open
        case let .graded(picked, answer):
            if index == answer { return .correct }
            if index == picked { return .wrong }
            return .dimmed
        }
    }

    private func accessibilityValue(for index: Int) -> String {
        switch state(for: index) {
        case .open: return ""
        case .correct:
            if case let .graded(picked, _) = phase, picked == index {
                return "Correct. This was your answer."
            }
            return "This was the correct answer."
        case .wrong: return "Incorrect. This was your answer."
        case .dimmed: return "Not the answer, not selected."
        }
    }

    private var emphasisedIndex: Int? {
        if case let .graded(_, answer) = phase { return answer }
        return nil
    }

    private var gradedTargetOpponent: OpponentSide? {
        guard case .graded = phase else { return nil }
        return ShotAdvisor.verdict(for: position).targetOpponent
    }

    private func ringColor(for index: Int) -> Color {
        switch state(for: index) {
        case .open: return Theme.Surface.ball
        case .correct: return Theme.rightGreen
        case .wrong: return Theme.wrongRed
        case .dimmed: return Color(white: 0.55)
        }
    }

    private func lineColor(for index: Int) -> Color {
        switch state(for: index) {
        case .open: return Theme.Surface.ball.opacity(0.7)
        case .correct: return Theme.rightGreen
        case .wrong: return Theme.wrongRed.opacity(0.8)
        case .dimmed: return .white.opacity(0.2)
        }
    }

    private func isOnScreen(_ p: CGPoint, in size: CGSize) -> Bool {
        p.x > -30 && p.x < size.width + 30 && p.y > -30 && p.y < size.height + 30
    }
}

/// One aim target's caption: the shot shape, and nothing else.
struct AimTargetLabel: View {
    enum State { case open, correct, wrong, dimmed }

    let shot: Shot
    let state: State

    var body: some View {
        Text(shot.type.label)
            .font(.system(size: 15, weight: .heavy))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .foregroundStyle(foreground)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity)
            .background(background, in: Capsule())
            .overlay(Capsule().strokeBorder(stroke, lineWidth: 1.5))
            .shadow(color: .black.opacity(0.5), radius: 6, y: 3)
            // The tap area is the whole allotted box, not the drawn pill, so a
            // short caption like "Lob" is no harder to hit than "Put it away".
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
    }

    private var foreground: Color {
        switch state {
        case .open: return Theme.Surface.play
        case .correct, .wrong: return .white
        case .dimmed: return .white.opacity(0.8)
        }
    }

    private var background: Color {
        switch state {
        case .open: return Theme.Surface.ball
        case .correct: return Theme.rightGreen
        case .wrong: return Theme.wrongRed
        case .dimmed: return Color(white: 0.16).opacity(0.86)
        }
    }

    private var stroke: Color {
        switch state {
        case .open: return .white.opacity(0.55)
        case .correct, .wrong: return .white.opacity(0.75)
        case .dimmed: return .white.opacity(0.22)
        }
    }
}

// MARK: - SceneKit host

/// The SceneKit side. Rebuilt when the position changes; the aim rings are
/// swapped in place when only the grading state changes, so answering a ball
/// never tears down and re-lights the whole court.
private struct CourtSceneView: UIViewRepresentable {
    let position: RallyPosition
    let camera: CourtCamera
    let aimPoints: [CourtPoint]
    let colors: [Color]
    let emphasised: Int?

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .clear
        view.allowsCameraControl = false
        view.autoenablesDefaultLighting = false
        view.antialiasingMode = .multisampling2X
        view.rendersContinuously = false
        view.isUserInteractionEnabled = false
        view.preferredFramesPerSecond = 30
        context.coordinator.rebuild(view, position: position, camera: camera)
        context.coordinator.updateAims(view, points: aimPoints, colors: colors, emphasised: emphasised)
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        if context.coordinator.positionID != position.id {
            context.coordinator.rebuild(view, position: position, camera: camera)
        }
        context.coordinator.updateAims(view, points: aimPoints, colors: colors, emphasised: emphasised)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var positionID: String?
        private var aimRoot: SCNNode?

        func rebuild(_ view: SCNView, position: RallyPosition, camera: CourtCamera) {
            let scene = CourtScene.make(for: position, camera: camera)
            let aims = SCNNode()
            aims.name = "aims"
            scene.rootNode.addChildNode(aims)
            aimRoot = aims
            view.scene = scene
            view.pointOfView = scene.rootNode.childNode(withName: "camera", recursively: false)
            positionID = position.id
        }

        func updateAims(_ view: SCNView, points: [CourtPoint], colors: [Color], emphasised: Int?) {
            guard let aimRoot else { return }
            aimRoot.childNodes.forEach { $0.removeFromParentNode() }
            for (index, point) in points.enumerated() {
                let color = colors[safe: index] ?? Theme.Surface.ball
                aimRoot.addChildNode(CourtScene.aimTarget(
                    at: point, color: color, emphasised: index == emphasised
                ))
            }
            view.setNeedsDisplay()
        }
    }
}
