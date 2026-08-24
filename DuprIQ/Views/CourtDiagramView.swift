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
                       ox: originX, oy: originY, kind: .opponent)
                marker(at: position.opponentRight, scale: scale, w: w, h: h,
                       ox: originX, oy: originY, kind: .opponent)
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

    private enum MarkerKind {
        case you, partner, opponent

        var color: Color {
            switch self {
            case .you: return .yellow
            case .partner: return Color.yellow.opacity(0.55)
            case .opponent: return Color(white: 0.95)
            }
        }

        var initial: String {
            switch self {
            case .you: return "You"
            case .partner: return "P"
            case .opponent: return ""
            }
        }
    }

    private func marker(
        at point: CourtPoint, scale: Double, w: Double, h: Double,
        ox: Double, oy: Double, kind: MarkerKind
    ) -> some View {
        let size = 22.0
        return ZStack {
            Circle()
                .fill(kind.color)
                .overlay(Circle().stroke(Color.black.opacity(0.45), lineWidth: 1.5))
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

    private var accessibilityDescription: String {
        """
        \(position.phase.title). You are \(position.yourZone.label.lowercased()). \
        Your partner is \(position.partnerZone.label.lowercased()). \
        Opponents: \(position.opponentLeftZone.label.lowercased()) on the left, \
        \(position.opponentRightZone.label.lowercased()) on the right. \
        The ball is \(position.ballHeight.label.lowercased()). \(position.scoreLine).
        """
    }
}
