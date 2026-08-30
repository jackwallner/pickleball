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
/// **The screen is a court over a panel, and the split is the fix for the
/// worst thing in the first two builds.** The captions used to be pills laid
/// out on the court beside their rings, and they could not be: a standing eye
/// sees the far court at a grazing angle, so twenty feet of depth is two
/// hundred points of screen, and four pills do not fit around four rings in
/// two hundred points. Every audit screenshot showed a label sitting on the
/// target it named. The text now lives in a panel below the court, one button
/// per option, and what is left on each ring is a numbered badge smaller than
/// the ring it sits in.
///
/// Nothing is handed back by that move. The panel says the shot SHAPE, which
/// is what the pills said; the place is still the ring, the ball's height is
/// still a thing you look at, and the four sets of feet are still the question.
/// What the panel buys is the half of the display that used to be empty near
/// court, which becomes four buttons a thumb can hit.
struct CourtPOVView: View {

    enum Phase: Equatable {
        case deciding
        /// The picked option and the correct one. Both are needed: the ring the
        /// player chose has to stay visible next to the one they should have.
        case graded(picked: Int, answer: Int)

        var isGraded: Bool { if case .graded = self { return true }; return false }
    }

    /// Where this court is drawn, which is the only thing that changes between
    /// the two callers.
    ///
    /// The full-bleed drill screen has a HUD across the top and an option panel
    /// across the bottom that the verdict card later slides in over. Inside a
    /// session runner the same court is a card in a scrolling column: same two
    /// bands, both smaller, and no HUD to speak of.
    enum Chrome {
        case fullBleedDrill
        case embedded

        func topInset(in size: CGSize) -> CGFloat {
            self == .fullBleedDrill ? 104 : 12
        }

        /// The band at the bottom the option panel occupies, and that the
        /// camera therefore refuses to put anything readable into.
        ///
        /// On the drill screen this is also the band the verdict card fills, so
        /// grading a ball swaps one for the other and the court above does not
        /// move a pixel. That is the promise the whole screen is built on.
        func optionBand(in size: CGSize) -> CGFloat {
            switch self {
            case .fullBleedDrill: return min(max(size.height * 0.44, 250), 380)
            case .embedded: return min(max(size.height * 0.40, 132), 200)
            }
        }

        var isCompact: Bool { self == .embedded }
    }

    let position: RallyPosition
    let options: [Shot]
    let aimPoints: [CourtPoint]
    let phase: Phase
    /// Nil while the ball is being graded, which is how the view is made
    /// read-only without `.disabled()` dimming the panel.
    var onPick: ((Int) -> Void)?
    var chrome: Chrome = .fullBleedDrill
    /// The line above the buttons. The drill screen asks the question here;
    /// inside a session runner the runner has already asked it above the card.
    var prompt: String?

    /// No player initial is drawn above this, because the HUD lives up there.
    private static let playerLabelFloor: CGFloat = 152

    /// How much of the bottom of the frame is reserved for the option panel,
    /// and so for the verdict card that replaces it.
    ///
    /// `DrillSessionView` caps the card to this, and `CourtCamera` is fitted
    /// above it. The two have to be the same number or one of them is wrong:
    /// a card taller than the reserve covers a ring, and a reserve taller than
    /// the card wastes court.
    static func verdictBandHeight(in size: CGSize) -> CGFloat {
        Chrome.fullBleedDrill.optionBand(in: size)
    }

    /// The camera is fitted to the frame it will actually be drawn in, minus
    /// the parts of that frame something else is drawn over.
    ///
    /// Aspect ratio and both chrome bands are inputs to the fit, not details.
    /// The angle needed to contain the court's width depends on how wide the
    /// frame is, and the angle needed to contain it vertically depends on how
    /// much of the height is left after the HUD and the panel take theirs.
    private func camera(for size: CGSize) -> CourtCamera {
        guard size.height > 0 else { return CourtCamera.viewing(position, aiming: aimPoints) }
        return CourtCamera.viewing(
            position,
            aiming: aimPoints,
            aspect: Double(size.width / size.height),
            topFraction: Double(chrome.topInset(in: size) / size.height),
            bottomFraction: Double(chrome.optionBand(in: size) / size.height)
        )
    }

    var body: some View {
        GeometryReader { geo in
            let camera = camera(for: geo.size)
            let placements = layout(with: camera, in: geo.size)
            ZStack(alignment: .bottom) {
                CourtSceneView(
                    position: position,
                    camera: camera,
                    aimPoints: aimPoints,
                    colors: options.indices.map { ringColor(for: $0) },
                    emphasised: emphasisedIndex
                )
                .accessibilityHidden(true)

                tethers(placements)
                playerLabels(with: camera, in: geo.size)
                ringBadges(placements)

                optionPanel(placements, in: geo.size)
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
            in: size,
            topInset: chrome.topInset(in: size),
            bottomInset: chrome.optionBand(in: size)
        )
    }

    /// A short line from a badge back to its ring, drawn only for a badge that
    /// a neighbour pushed off centre. Most balls draw none of these.
    private func tethers(_ placements: [AimLabelLayout.Placement]) -> some View {
        Canvas { context, _ in
            for placement in placements where placement.isOffset {
                var path = Path()
                path.move(to: placement.badge)
                path.addLine(to: placement.anchor)
                context.stroke(
                    path,
                    with: .color(lineColor(for: placement.index)),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [3, 3])
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
            // Clamped clear of the HUD. An opponent at their own baseline
            // projects high in the frame, and the initial floating over their
            // head landed on top of "SHOT 1 OF 4"; a badge that collides with
            // the scoreboard names nobody and breaks the header at the same
            // time. Pushed down it sits on the body instead, which still reads.
            if let raw = camera.project(point, height: 5.3, in: size),
               isOnScreen(raw, in: size) {
                let floor = chrome == .fullBleedDrill ? Self.playerLabelFloor : 14
                let screen = CGPoint(x: raw.x, y: max(raw.y, floor))
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

    /// The numbered badge on each ring, which is also a tap target.
    ///
    /// The app's claim is that you answer by AIMING, and the natural gesture
    /// for that is a tap on the ring you want, so the badge carries a 48 point
    /// hit area around its 26 points of ink. The panel button below is the same
    /// answer by another route, for a thumb that does not want to reach up the
    /// screen and for VoiceOver, which cannot aim at anything.
    @ViewBuilder
    private func ringBadges(_ placements: [AimLabelLayout.Placement]) -> some View {
        ForEach(placements, id: \.index) { placement in
            AimBadge(number: placement.index + 1, state: state(for: placement.index))
                .frame(width: 48, height: 48)
                .contentShape(Circle())
                .position(placement.badge)
                .onTapGesture { onPick?(placement.index) }
                .allowsHitTesting(onPick != nil)
                .accessibilityHidden(true)
        }
    }

    // MARK: - The option panel

    /// Four buttons, laid out as a map of the four rings.
    ///
    /// The grid is not a list: the top row is the two targets further up the
    /// court and the bottom row the two nearer ones, each row left to right, so
    /// the button's place in the panel matches the ring's place on the court
    /// before anybody reads a number. The numbers are the backstop.
    @ViewBuilder
    private func optionPanel(
        _ placements: [AimLabelLayout.Placement], in size: CGSize
    ) -> some View {
        let rows = AimLabelLayout.panelOrder(placements)
        VStack(spacing: chrome.isCompact ? 6 : 10) {
            if let prompt, !chrome.isCompact {
                Text(prompt)
                    .font(Theme.display(19))
                    .foregroundStyle(.white)
                    .accessibilityAddTraits(.isHeader)
            }
            ForEach(rows.indices, id: \.self) { row in
                HStack(spacing: chrome.isCompact ? 6 : 10) {
                    ForEach(rows[row], id: \.index) { placement in
                        button(for: placement.index)
                    }
                    // Keeps a lone button in an odd row the width of the one
                    // above it rather than stretched across the panel.
                    if rows[row].count == 1 && rows.count > 1 {
                        Color.clear.frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding(.horizontal, chrome.isCompact ? 8 : 14)
        .padding(.top, chrome.isCompact ? 8 : 14)
        .padding(.bottom, chrome.isCompact ? 8 : 22)
        .frame(maxWidth: Theme.readableContentWidth)
        .frame(maxWidth: .infinity)
        .frame(height: chrome.optionBand(in: size), alignment: .bottom)
        .background(
            // A ramp rather than an edge. The court runs under the panel, so a
            // hard line across it would read as the render being cut off.
            LinearGradient(
                colors: [.black.opacity(0), .black.opacity(0.55), .black.opacity(0.82)],
                startPoint: .top, endPoint: .bottom
            )
            .allowsHitTesting(false)
        )
    }

    @ViewBuilder
    private func button(for index: Int) -> some View {
        if let shot = options[safe: index], let caption = captions[safe: index] {
            AimOptionButton(
                number: index + 1,
                title: caption.title,
                detail: caption.detail,
                state: state(for: index),
                compact: chrome.isCompact,
                action: { onPick?(index) }
            )
            .allowsHitTesting(onPick != nil)
            .accessibilityLabel(shot.label)
            .accessibilityHint("Aims \(shot.target.label)")
            .accessibilityValue(accessibilityValue(for: index))
            .accessibilityIdentifier("shot-\(index)")
        }
    }

    private var captions: [(title: String, detail: String?)] {
        ShotAiming.captions(for: options)
    }

    private func state(for index: Int) -> AimTargetState {
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

/// How one option is faring: before the tap, and after it.
enum AimTargetState { case open, correct, wrong, dimmed }

/// The numbered badge drawn on a ring.
///
/// Optic yellow, which everywhere else in this app belongs to the ball and the
/// aim rings alone. That rule is not being broken here: the badge IS the aim
/// ring's label, and matching it to the ring's own colour is what makes the
/// pairing with the panel button read at a glance.
struct AimBadge: View {
    let number: Int
    let state: AimTargetState

    var body: some View {
        Text("\(number)")
            .font(.system(size: 14, weight: .black, design: .rounded))
            .foregroundStyle(ink)
            .frame(width: AimLabelLayout.badgeSize, height: AimLabelLayout.badgeSize)
            .background(fill, in: Circle())
            .overlay(Circle().strokeBorder(.black.opacity(0.35), lineWidth: 1.5))
            .shadow(color: .black.opacity(0.55), radius: 4, y: 2)
    }

    private var fill: Color {
        switch state {
        case .open: return Theme.Surface.ball
        case .correct: return Theme.rightGreen
        case .wrong: return Theme.wrongRed
        case .dimmed: return Color(white: 0.42)
        }
    }

    private var ink: Color {
        switch state {
        case .open: return Theme.Surface.play
        case .correct, .wrong, .dimmed: return .white
        }
    }
}

/// One option, in the panel under the court.
///
/// Dark and neutral, with the number in the ring's own optic yellow. Filling
/// four buttons with optic yellow would put more of it on the screen than the
/// ball and the rings have between them, and the one thing this render cannot
/// afford is for the ball to stop being the brightest thing in the frame.
struct AimOptionButton: View {
    let number: Int
    let title: String
    /// The place, added only when two options share a shape. See
    /// `ShotAiming.captions`.
    var detail: String?
    let state: AimTargetState
    var compact: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: compact ? 7 : 10) {
                Text("\(number)")
                    .font(.system(size: compact ? 12 : 14, weight: .black, design: .rounded))
                    .foregroundStyle(numberInk)
                    .frame(width: compact ? 20 : 24, height: compact ? 20 : 24)
                    .background(numberFill, in: Circle())

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: compact ? 13 : 16, weight: .heavy))
                        .foregroundStyle(.white)
                    if let detail {
                        Text(detail)
                            .font(.system(size: compact ? 10 : 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.72))
                    }
                }
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, compact ? 9 : 12)
            .frame(maxWidth: .infinity)
            .frame(maxHeight: .infinity)
            .frame(minHeight: compact ? 46 : 62)
            .background(fill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(stroke, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    private var fill: Color {
        switch state {
        case .open: return Color(red: 0.09, green: 0.15, blue: 0.18).opacity(0.92)
        case .correct: return Theme.rightGreen
        case .wrong: return Theme.wrongRed
        case .dimmed: return Color(white: 0.14).opacity(0.86)
        }
    }

    private var stroke: Color {
        switch state {
        case .open: return .white.opacity(0.30)
        case .correct, .wrong: return .white.opacity(0.75)
        case .dimmed: return .white.opacity(0.16)
        }
    }

    private var numberFill: Color {
        switch state {
        case .open: return Theme.Surface.ball
        case .correct, .wrong: return .white.opacity(0.92)
        case .dimmed: return Color(white: 0.42)
        }
    }

    private var numberInk: Color {
        switch state {
        case .open: return Theme.Surface.play
        case .correct: return Theme.rightGreen
        case .wrong: return Theme.wrongRed
        case .dimmed: return .white
        }
    }
}

// MARK: - SceneKit host

/// The SceneKit side. Rebuilt when the position changes; the aim rings are
/// swapped in place when only the grading state changes, so answering a ball
/// never tears down and re-lights the whole court.
@MainActor
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
        // SceneKit publishes an accessibility element for EVERY node, so the
        // court exported roughly two hundred unlabelled "Other" elements: forty
        // net strands, every line box, both players' limbs. VoiceOver had to be
        // swiped through all of it to reach the four options, and XCUITest
        // queries slowed to the point of timing out. `.accessibilityHidden` on
        // the SwiftUI wrapper does not reach inside a hosted UIView, so it is
        // set on the view itself. Nothing is lost: the court's description is
        // spoken by `CourtPOVView` as one label.
        view.isAccessibilityElement = false
        view.accessibilityElementsHidden = true
        context.coordinator.rebuild(view, position: position, camera: camera)
        context.coordinator.updateAims(view, points: aimPoints, colors: colors, emphasised: emphasised)
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        if context.coordinator.positionID != position.id {
            context.coordinator.rebuild(view, position: position, camera: camera)
        } else {
            context.coordinator.updateCamera(view, camera: camera)
        }
        context.coordinator.updateAims(view, points: aimPoints, colors: colors, emphasised: emphasised)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    @MainActor
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
            updateCamera(view, camera: camera)
            positionID = position.id
        }

        func updateCamera(_ view: SCNView, camera: CourtCamera) {
            guard
                let cameraNode = view.scene?.rootNode.childNode(withName: "camera", recursively: false),
                let scnCamera = cameraNode.camera
            else { return }
            camera.apply(to: scnCamera)
            cameraNode.position = camera.scenePosition
            cameraNode.eulerAngles = camera.eulerAngles
            view.pointOfView = cameraNode
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
