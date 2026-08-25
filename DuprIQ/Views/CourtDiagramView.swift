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

    private let surface = Color(red: 0.16, green: 0.42, blue: 0.62)
    private let kitchen = Color(red: 0.72, green: 0.31, blue: 0.22)

    var body: some View {
        GeometryReader { geo in
            let scale = min(geo.size.width / Court.width,
                            geo.size.height / Court.length)
            let w = Court.width * scale
            let h = Court.length * scale
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
                    .frame(width: w, height: Court.kitchenDepth * 2 * scale)
                    .offset(x: originX,
                            y: originY + toScreenY(Court.theirKitchenLine, scale: scale, height: h))

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
        .aspectRatio(Court.width / Court.length, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
    }

    // MARK: - Pieces

    private func lines(scale: Double, width w: Double, height h: Double) -> some View {
        Path { path in
            // Net.
            path.move(to: CGPoint(x: 0, y: toScreenY(Court.netY, scale: scale, height: h)))
            path.addLine(to: CGPoint(x: w, y: toScreenY(Court.netY, scale: scale, height: h)))
            // Both kitchen lines.
            for y in [Court.ourKitchenLine, Court.theirKitchenLine] {
                path.move(to: CGPoint(x: 0, y: toScreenY(y, scale: scale, height: h)))
                path.addLine(to: CGPoint(x: w, y: toScreenY(y, scale: scale, height: h)))
            }
            // Center lines, which stop at the kitchen on both sides.
            path.move(to: CGPoint(x: w / 2, y: toScreenY(0, scale: scale, height: h)))
            path.addLine(to: CGPoint(x: w / 2, y: toScreenY(Court.ourKitchenLine, scale: scale, height: h)))
            path.move(to: CGPoint(x: w / 2, y: toScreenY(Court.theirKitchenLine, scale: scale, height: h)))
            path.addLine(to: CGPoint(x: w / 2, y: toScreenY(Court.length, scale: scale, height: h)))
        }
        .stroke(Color.white.opacity(0.85), lineWidth: 1.5)
        .frame(width: w, height: h)
    }

    private enum MarkerKind: Equatable {
        case you, partner
        case opponent(OpponentSide)

        var color: Color {
            switch self {
            case .you: return .yellow
            case .partner: return Color.yellow.opacity(0.55)
            case .opponent: return Color(white: 0.95)
            }
        }

        /// Every marker is captioned. Two blank white circles cannot carry an
        /// answer that says "hit the left opponent".
        var initial: String {
            switch self {
            case .you: return "You"
            case .partner: return "P"
            case .opponent(let side): return side.marker
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
        return ZStack {
            if isTarget {
                Circle()
                    .stroke(Color.accentColor, lineWidth: 3)
                    .frame(width: size + 10, height: size + 10)
            }
            Circle()
                .fill(kind.color)
                .overlay(Circle().stroke(Color.black.opacity(0.45), lineWidth: 1.5))
                .frame(width: size, height: size)
            if !kind.initial.isEmpty {
                Text(kind.initial)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.black)
            }
        }
        .frame(width: size, height: size)
        .offset(
            x: ox + point.x * scale - size / 2,
            y: oy + toScreenY(point.y, scale: scale, height: h) - size / 2
        )
    }

    private func ball(scale: Double, ox: Double, oy: Double, h: Double) -> some View {
        let size = 13.0
        return Circle()
            .fill(Color(red: 0.85, green: 0.95, blue: 0.2))
            .overlay(Circle().stroke(Color.black.opacity(0.5), lineWidth: 1))
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

    /// The whole decision, spoken.
    ///
    /// The task is reading feet, so an accessible description that stops at
    /// "opponents at the kitchen" hides the exact thing being graded: which
    /// opponent is short, how wide the seam between them is, and where the
    /// contact sits relative to the middle.
    private var accessibilityDescription: String {
        var parts: [String] = [
            position.phase.title + ".",
            "You are \(position.yourZone.label.lowercased()), hitting \(position.contactSideLabel).",
            "Your partner is \(position.partnerZone.label.lowercased()).",
            "Left opponent \(position.opponentLeftZone.label.lowercased()), right opponent \(position.opponentRightZone.label.lowercased()).",
        ]
        if let lagging = position.laggingOpponentSide {
            parts.append("\(lagging.label.capitalizedFirst) has not reached the line.")
        } else if position.opponentsBothAtKitchen {
            parts.append("Both opponents are set at the line.")
        }
        parts.append(
            position.isMiddleOpen
                ? "They are about \(Int(position.opponentSpread.rounded())) feet apart, so the middle is open."
                : "They are about \(Int(position.opponentSpread.rounded())) feet apart, covering the middle."
        )
        parts.append("The ball is \(position.ballHeight.label.lowercased()).")
        if let highlight {
            parts.append("The answer targets \(highlight.label), marked \(highlight.marker).")
        }
        parts.append("Score, \(position.scoreLine).")
        return parts.joined(separator: " ")
    }
}
