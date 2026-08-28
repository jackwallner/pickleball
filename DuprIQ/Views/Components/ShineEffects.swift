import SwiftUI

/// One-shot diagonal shine sweep, the slot-machine "you won" gleam. Bump
/// `trigger` to fire; a bright band sweeps across once and disappears.
struct ShineSweep: ViewModifier {
    var trigger: Int
    var corner: CGFloat = 14

    @State private var phase: CGFloat = -1

    /// Drawn in a Canvas, not as an offset gradient view, and that is not a
    /// style choice. The band is parked a full width off to the left between
    /// sweeps; as a real subview, its geometry leaked into whatever it was
    /// attached to, and every shined button ended up reporting a hit and
    /// VoiceOver frame ~1000pt wide, centered off-screen (neither clipShape,
    /// clipped, nor drawingGroup shrank it back). A Canvas physically cannot
    /// draw outside its own bounds, so the leak has nowhere to go.
    func body(content: Content) -> some View {
        content
            .overlay {
                Canvas { context, size in
                    guard phase > -1 else { return }
                    let band = max(size.width * 0.42, 60)
                    context.clip(to: Path(
                        roundedRect: CGRect(origin: .zero, size: size),
                        cornerRadius: corner,
                        style: .continuous
                    ))
                    context.translateBy(
                        x: phase * (size.width + band),
                        y: size.height / 2
                    )
                    context.rotate(by: .degrees(16))
                    let rect = CGRect(
                        x: -band / 2,
                        y: -size.height * 1.2,
                        width: band,
                        height: size.height * 2.4
                    )
                    context.fill(
                        Path(rect),
                        with: .linearGradient(
                            Gradient(colors: [
                                .clear, .white.opacity(0.08), .white.opacity(0.62), .white.opacity(0.08), .clear,
                            ]),
                            startPoint: CGPoint(x: rect.minX, y: 0),
                            endPoint: CGPoint(x: rect.maxX, y: 0)
                        )
                    )
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            .onChange(of: trigger) { _, _ in
                guard trigger > 0 else { return }
                phase = -1
                withAnimation(.easeInOut(duration: 0.85)) { phase = 1.4 }
            }
    }
}

/// Horizontal shake for wrong answers. Animate `travels` from 0 to N.
struct ShakeEffect: GeometryEffect {
    var travels: CGFloat

    var animatableData: CGFloat {
        get { travels }
        set { travels = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 7 * sin(travels * .pi * 2), y: 0))
    }
}

extension View {
    func shine(trigger: Int, corner: CGFloat = 14) -> some View {
        modifier(ShineSweep(trigger: trigger, corner: corner))
    }

    /// Celebration glow around a winning element.
    func winGlow(_ color: Color, active: Bool) -> some View {
        shadow(color: color.opacity(active ? 0.58 : 0), radius: active ? 16 : 0, y: 0)
    }
}
