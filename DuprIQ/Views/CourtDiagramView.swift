import SwiftUI

/// The hero view: one rally position drawn as a court, seen from behind your
/// own baseline.
///
/// Screen space is flipped against court space, because a player reads a court
/// with their own end at the bottom. Everything is laid out in normalised court
/// feet and scaled once, so the diagram is resolution independent and the same
/// on a phone and an iPad.
struct CourtDiagramView: View {
    let position: RallyPosition
    /// The opponent the graded answer is aimed at, once there is one. Naming a
    /// target in the explanation is only coaching if the player can see which
    /// of the two identical markers it means.
    let highlight: OpponentSide?

    init(position: RallyPosition, highlight: OpponentSide? = nil) {
        self.position = position
        self.highlight = highlight
    }

    private let surface = Theme.Surface.play
    private let kitchen = Theme.Surface.kitchen

    var body: some View {
        GeometryReader { geo in
            let scale = min(geo.size.width / CourtGeometry.width,
                            geo.size.height / CourtGeometry.length)
            let w = CourtGeometry.width * scale
            let h = CourtGeometry.length * scale
            let originX = (geo.size.width - w) / 2
            let originY = (geo.size.height - h) / 2

            ZStack(alignment: .topLeading) {
                surface
                    .frame(width: w, height: h)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .offset(x: originX, y: originY)

                // Both kitchens, drawn as one band across the net.
                Rectangle()
                    .fill(kitchen.opacity(0.55))
                    .frame(width: w, height: CourtGeometry.kitchenDepth * 2 * scale)
                    .offset(x: originX,
                            y: originY + toScreenY(CourtGeometry.theirKitchenLine, scale: scale, height: h))

                lines(scale: scale, width: w, height: h)
                    .offset(x: originX, y: originY)

                marker(at: position.opponentLeft, scale: scale, w: w, h: h,
                       ox: originX, oy: originY, kind: .opponent(.left))
                marker(at: position.opponentRight, scale: scale, w: w, h: h,
                       ox: originX, oy: originY, kind: .opponent(.right))
                marker(at: position.partner, scale: scale, w: w, h: h,
                       ox: originX, oy: originY, kind: .partner)
                marker(at: position.you, scale: scale, w: w, h: h,
                       ox: originX, oy: originY, kind: .you)

                ball(scale: scale, ox: originX, oy: originY, h: h)
            }
        }
        .aspectRatio(CourtGeometry.width / CourtGeometry.length, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
    }

    // MARK: - Pieces

    private func lines(scale: Double, width w: Double, height h: Double) -> some View {
        Path { path in
            // Net.
            path.move(to: CGPoint(x: 0, y: toScreenY(CourtGeometry.netY, scale: scale, height: h)))
            path.addLine(to: CGPoint(x: w, y: toScreenY(CourtGeometry.netY, scale: scale, height: h)))
            // Both kitchen lines.
            for y in [CourtGeometry.ourKitchenLine, CourtGeometry.theirKitchenLine] {
                path.move(to: CGPoint(x: 0, y: toScreenY(y, scale: scale, height: h)))
                path.addLine(to: CGPoint(x: w, y: toScreenY(y, scale: scale, height: h)))
            }
            // Center lines, which stop at the kitchen on both sides.
            path.move(to: CGPoint(x: w / 2, y: toScreenY(0, scale: scale, height: h)))
            path.addLine(to: CGPoint(x: w / 2, y: toScreenY(CourtGeometry.ourKitchenLine, scale: scale, height: h)))
            path.move(to: CGPoint(x: w / 2, y: toScreenY(CourtGeometry.theirKitchenLine, scale: scale, height: h)))
            path.addLine(to: CGPoint(x: w / 2, y: toScreenY(CourtGeometry.length, scale: scale, height: h)))
        }
        .stroke(Color.white.opacity(0.85), lineWidth: 1.5)
        .frame(width: w, height: h)
    }

    private enum MarkerKind: Equatable {
        case you, partner
        case opponent(OpponentSide)

        /// Your team is light, theirs is dark, and NEITHER is the optic yellow
        /// of the ball. The previous scheme painted you and your partner in two
        /// shades of yellow next to a yellow ball, so the one object whose
        /// position the whole question turns on was the hardest thing on the
        /// diagram to find.
        var fill: Color {
            switch self {
            case .you, .partner: return Color(white: 0.97)
            case .opponent: return Color(red: 0.09, green: 0.13, blue: 0.19)
            }
        }

        var stroke: Color {
            switch self {
            case .you: return Theme.Surface.ball
            case .partner: return Color(white: 0.55)
            case .opponent: return Color(white: 0.92)
            }
        }

        var caption: Color {
            switch self {
            case .you, .partner: return Color(red: 0.09, green: 0.13, blue: 0.19)
            case .opponent: return Color(white: 0.97)
            }
        }

        /// Every marker is captioned. Two blank circles cannot carry an answer
        /// that says "hit the left opponent".
        ///
        /// One character each, including yours. "You" was three characters in a
        /// 22pt circle: `Text` is not clipped by a `.frame`, so it set the
        /// ZStack's width, spilled past the circle and rendered as an oversized
        /// yellow capsule roughly three times the size of every other marker.
        var initial: String {
            switch self {
            case .you: return "Y"
            case .partner: return "P"
            case .opponent(let side): return side.marker
            }
        }

        var spokenName: String {
            switch self {
            case .you: return "You"
            case .partner: return "Your partner"
            case .opponent(let side): return side.label.capitalizedFirst
            }
        }

        var opponentSide: OpponentSide? {
            if case .opponent(let side) = self { return side }
            return nil
        }
    }

    private func marker(
        at point: CourtPoint, scale: Double, w: Double, h: Double,
        ox: Double, oy: Double, kind: MarkerKind
    ) -> some View {
        let size = 22.0
        let isTarget = kind.opponentSide != nil && kind.opponentSide == highlight
        return Circle()
            .fill(kind.fill)
            .overlay(Circle().strokeBorder(kind.stroke, lineWidth: 1.5))
            .overlay(
                Text(kind.initial)
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(kind.caption)
            )
            // The target halo is an overlay too, so a highlighted marker cannot
            // grow the layout out from under the one next to it.
            .overlay(
                Circle()
                    .strokeBorder(isTarget ? Theme.Surface.ball : .clear, lineWidth: 3)
                    .padding(-5)
            )
            .frame(width: size, height: size)
            .offset(
                x: ox + point.x * scale - size / 2,
                y: oy + toScreenY(point.y, scale: scale, height: h) - size / 2
            )
            .accessibilityHidden(true)
    }

    private func ball(scale: Double, ox: Double, oy: Double, h: Double) -> some View {
        let size = 12.0
        return Circle()
            .fill(Theme.Surface.ball)
            .overlay(Circle().strokeBorder(Color.black.opacity(0.55), lineWidth: 1.5))
            .frame(width: size, height: size)
            .offset(
                x: ox + position.contact.x * scale - size / 2,
                y: oy + toScreenY(position.contact.y, scale: scale, height: h) - size / 2
            )
    }

    /// Court feet to screen points, flipped so your baseline sits at the bottom.
    private func toScreenY(_ courtY: Double, scale: Double, height: Double) -> Double {
        height - courtY * scale
    }

    /// The overhead view speaks the same description the first-person court
    /// does. See `RallyPosition.spokenDescription`.
    private var accessibilityDescription: String {
        position.spokenDescription(highlight: highlight)
    }
}
