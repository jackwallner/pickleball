import SwiftUI

/// A one-shot confetti burst. Bump `trigger` to fire. Drawn with Canvas so a
/// burst costs nothing once it ends.
///
/// It launches from `sourceRect` when the host knows what was celebrated (the
/// correct answer row, say), otherwise from `origin`. Firing from the winning
/// element is the whole point: a burst that always erupts from the middle of
/// the screen doesn't celebrate anything in particular.
///
/// The motion is deliberately not "point source under gravity" (which reads as
/// a firework, not a celebration). Pieces launch along a wide upward fan from
/// across the source's WIDTH, decelerate through linear air drag toward a slow
/// terminal fall, sway as they tumble, and flip end over end (the width squash
/// fakes the third dimension). Ribbons mixed in with the chips keep the shapes
/// from reading as uniform.
struct ConfettiBurst: View {
    var trigger: Int
    var origin: UnitPoint = .center
    var particleCount: Int = 26
    /// The celebrated element, in the same coordinate space this view fills.
    var sourceRect: CGRect?

    @State private var firedAt: Date?
    @State private var seed: Int = 0
    /// Snapshotted at fire time: the source can move (or vanish) mid-flight,
    /// and the burst should keep the geometry it launched with.
    @State private var launchRect: CGRect?

    /// Gated centrally rather than at each of the seven call sites, because a
    /// celebration that one screen forgot to check is exactly the one a reader
    /// who turned it off will find. Reads the same key `AppSettings` writes,
    /// defaulting off for the professional audience.
    static var celebrationsEnabled: Bool {
        UserDefaults.standard.object(forKey: "settings.celebrations") as? Bool ?? false
    }

    private static let colors: [Color] = [
        Theme.court, Theme.ball, Theme.gold, Theme.slate, Theme.rightGreen, Theme.worksheet,
    ]
    private static let duration: Double = 2.0
    /// Air drag. Higher = the initial burst dies back faster into the drift.
    private static let drag: Double = 1.9
    private static let gravity: Double = 1100

    var body: some View {
        Group {
            if let firedAt {
                TimelineView(.animation) { context in
                    Canvas { canvas, size in
                        let t = context.date.timeIntervalSince(firedAt)
                        guard t < Self.duration else { return }
                        draw(in: &canvas, size: size, time: t)
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .onChange(of: trigger) { _, _ in
            guard trigger > 0, Self.celebrationsEnabled else { return }
            seed = trigger
            launchRect = sourceRect
            firedAt = Date()
        }
    }

    /// Where a piece is born: spread along the source's top edge, so a wide row
    /// erupts along its whole width like a party popper rather than spitting
    /// everything out of one pixel.
    private func launchPoint(index: Int, count: Int, size: CGSize, random: inout SeededRandom) -> CGPoint {
        guard let rect = launchRect, rect.width > 1 else {
            return CGPoint(x: origin.x * size.width, y: origin.y * size.height)
        }
        let spread = (Double(index) + random.next(in: 0.15, 0.85)) / Double(count)
        return CGPoint(
            x: rect.minX + rect.width * spread,
            y: rect.midY - rect.height * 0.25
        )
    }

    private func draw(in canvas: inout GraphicsContext, size: CGSize, time: Double) {
        var random = SeededRandom(seed: UInt64(bitPattern: Int64(seed &* 7919 &+ 13)))
        let k = Self.drag
        let g = Self.gravity
        // Closed-form linear-drag ballistics: an initial kick that decays into
        // a gentle terminal-velocity fall. Cheap, stable, and it looks right.
        let decay = (1 - exp(-k * time)) / k

        for index in 0..<particleCount {
            let start = launchPoint(index: index, count: particleCount, size: size, random: &random)
            // Wide upward fan, biased outward from the center of the source.
            let side: Double = index.isMultiple(of: 2) ? 1 : -1
            let angle = -Double.pi / 2 + side * random.next(in: 0.06, 1.15)
            let speed = random.next(in: 340, 760)
            let vx = cos(angle) * speed
            let vy = sin(angle) * speed

            var x = start.x + CGFloat(vx * decay)
            let y = start.y + CGFloat((vy + g / k) * decay - g * time / k)
            guard y < size.height + 30, y > -60 else { continue }

            // Flutter: the piece sways as it tumbles, and slows its sway as it
            // falls, which is what makes paper look like paper.
            let swayPhase = random.next(in: 0, 6.28)
            let swaySpeed = random.next(in: 3.5, 7.0)
            let swayWidth = random.next(in: 4, 14)
            x += CGFloat(sin(time * swaySpeed + swayPhase) * swayWidth)

            let life = time / Self.duration
            let fade = life < 0.72 ? 1.0 : max(0, 1 - (life - 0.72) / 0.28)

            // End-over-end tumble. |cos| squashes the width to fake the flip.
            let spinSpeed = random.next(in: 4, 11) * (index.isMultiple(of: 3) ? -1 : 1)
            let spin = spinSpeed * time + swayPhase
            let tilt = random.next(in: -0.5, 0.5) + spin * 0.12

            let isRibbon = index % 5 == 0
            let w = isRibbon ? random.next(in: 3, 5) : random.next(in: 6, 11)
            let h = isRibbon ? random.next(in: 14, 22) : random.next(in: 6, 11)
            let squash = max(0.15, abs(cos(spin)))

            var piece = canvas
            piece.translateBy(x: x, y: y)
            piece.rotate(by: .radians(tilt))
            piece.scaleBy(x: squash, y: 1)
            piece.opacity = fade
            let rect = CGRect(x: -w / 2, y: -h / 2, width: w, height: h)
            piece.fill(
                Path(roundedRect: rect, cornerRadius: isRibbon ? 1 : 1.8),
                with: .color(Self.colors[index % Self.colors.count])
            )
        }
    }
}

/// Tiny deterministic generator so a burst renders identically every frame.
private struct SeededRandom {
    private var state: UInt64

    init(seed: UInt64) { state = seed == 0 ? 0x9E3779B9 : seed }

    private mutating func nextRaw() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }

    mutating func next(in low: Double, _ high: Double) -> Double {
        low + (high - low) * (Double(nextRaw() % 10_000) / 10_000)
    }
}
