import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Court design system: cool paper and slate surfaces, the deep blue of a
/// painted court as the primary, optic-ball orange for energy, gold for the
/// membership, and condensed sans display type. Every color adapts to dark mode
/// via dynamic providers.
///
/// The palette is deliberately *not* the one this shell arrived with. It came
/// through two other apps in the fleet and each left its own vocabulary in the
/// token names; a pickleball app's visual signals are the blue of the surface,
/// the terracotta of a non-volley zone, the optic yellow of the ball, and the
/// green of the surround. Names here follow those, not the previous domains.
enum Theme {
    // MARK: Brand
    //
    // Every accent is named after the thing it comes from, and the room accents
    // below use them semantically: blue for the court itself, green for the
    // soft game, steel for the walk to the line, ball-orange for pressure.

    /// Court blue. Primary actions, progress, selected states.
    /// 6.6:1 on white with white text on the fill, so it works as a CTA.
    static let court = Color(light: (0.05, 0.34, 0.64), dark: (0.42, 0.70, 1.0))
    /// Optic-ball orange. Energy moments: streaks, celebration, the pressure room.
    static let ball = Color(light: (0.70, 0.36, 0.15), dark: (0.91, 0.58, 0.33))
    /// Gold. Locks, "best value", membership highlights.
    static let gold = Color(light: (0.63, 0.47, 0.10), dark: (0.87, 0.72, 0.34))
    /// Steel blue. The third shot and transition room.
    static let slate = Color(light: (0.30, 0.36, 0.47), dark: (0.60, 0.69, 0.82))
    /// Surround green. The kitchen room, and nothing else. Kept distinct from
    /// `rightGreen` so a room accent never reads as a correctness mark.
    static let turf = Color(light: (0.13, 0.45, 0.24), dark: (0.42, 0.76, 0.50))

    // MARK: Surfaces

    /// Cool drawing-paper background in light, slate in dark
    /// (never pure white / pure black).
    static let background = Color(light: (0.937, 0.949, 0.961), dark: (0.070, 0.078, 0.094))
    /// Raised card surface.
    static let card = Color(light: (0.996, 1.0, 1.0), dark: (0.125, 0.141, 0.169))
    /// Slightly sunken surface for wells inside cards.
    static let well = Color(light: (0.902, 0.922, 0.941), dark: (0.094, 0.106, 0.129))
    /// Hairline stroke on cards.
    static let rule = Color(light: (0.796, 0.827, 0.859), dark: (0.235, 0.259, 0.302))

    // MARK: Ink

    // Contrast is not a style knob here. This app's readers skew 50+ and read
    // it on a couch in bad light, and tertiary ink carries the money disclosure
    // and the swipe instructions. Every level below clears WCAG AA (4.5:1) on
    // both backgrounds; tertiary used to sit at 2.8:1, which is decorative-text
    // territory. Re-check with a contrast calculator before lightening the paper.
    static let ink = Color(light: (0.09, 0.12, 0.16), dark: (0.93, 0.95, 0.97))
    /// 6.7:1 light / 7.7:1 dark.
    static let inkSecondary = Color(light: (0.31, 0.35, 0.41), dark: (0.70, 0.74, 0.79))
    /// 4.7:1 light / 5.9:1 dark.
    static let inkTertiary = Color(light: (0.39, 0.43, 0.49), dark: (0.60, 0.64, 0.70))

    // MARK: Worksheet and grading

    /// The card/working-panel stock, a shade cooler and brighter than `card`.
    /// Used for the faces of flashcards and for the numbered working panel, so
    /// both read as a page from a coach's notebook rather than another app
    /// surface. Pair it with `ruledGrid()` on the working panel.
    static let worksheet = Color(light: (0.980, 0.988, 1.0), dark: (0.918, 0.937, 0.957))
    static let worksheetEdge = Color(light: (0.769, 0.812, 0.859), dark: (0.635, 0.678, 0.729))
    /// The faint ruled grid drawn on worksheet surfaces. Low enough to sit
    /// behind text without fighting it at any Dynamic Type size.
    static let grid = Color(light: (0.05, 0.30, 0.55), dark: (0.10, 0.25, 0.45))
    /// Grading colors. Deliberately not `court`/`ball`: right and wrong have
    /// to read as a verdict, not as brand accents used elsewhere on the screen.
    static let rightGreen = Color(red: 0.12, green: 0.47, blue: 0.29)
    static let wrongRed = Color(red: 0.72, green: 0.17, blue: 0.16)

    // MARK: Type

    /// Display type for titles. Heavy condensed sans, the lettering of a
    /// scoreboard and a tournament draw sheet, not the serif of a members' club. `.width` needs iOS 16; the fallback keeps the weight.
    static func display(_ size: CGFloat, weight: Font.Weight = .heavy) -> Font {
        if #available(iOS 16.0, *) {
            return .system(size: size, weight: weight).width(.condensed)
        }
        return .system(size: size, weight: weight)
    }

    /// Numbers read as instrument readings, not prose: ampacities, AWG sizes,
    /// article numbers and percentages all use this so columns line up and a
    /// value never reflows differently from the one above it.
    static func numeric(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

static let cardCorner: CGFloat = 20
    static let deckCorner: CGFloat = 26
    /// Keeps reading and answering comfortable on iPad instead of stretching
    /// phone-sized interactions across the full window.
    static let readableContentWidth: CGFloat = 760
    static let wideContentWidth: CGFloat = 1120
}

/// Room identity: each room keeps its own accent so the four doors feel like
/// four places, not four list rows.
extension Room {
    var accent: Color {
        switch id {
        case DrillLibrary.basicsRoomID: return Theme.court
        case DrillLibrary.kitchenRoomID: return Theme.turf
        case DrillLibrary.transitionRoomID: return Theme.slate
        // The pressure room. Copper, the palette's energy accent, because it is
        // the room about hitting the ball hard and surviving one hit hard at you.
        default: return Theme.ball
        }
    }
}

/// The membership brand. The RevenueCat entitlement is `pro`; this is only
/// what readers see.
enum Membership {
    static let name = "DUPR IQ Pro"
}

/// The gold pill that marks anything behind the membership.
struct PlusBadge: View {
    var text: String = Membership.name

    var body: some View {
        Text(text)
            .font(.caption.weight(.heavy))
            .foregroundStyle(Theme.gold)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Theme.gold.opacity(0.15), in: Capsule())
    }
}

extension Color {
    /// Adaptive color from light/dark RGB triples.
    init(light: (Double, Double, Double), dark: (Double, Double, Double)) {
        #if canImport(UIKit)
        self.init(uiColor: UIColor { traits in
            let c = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: c.0, green: c.1, blue: c.2, alpha: 1)
        })
        #else
        self.init(red: light.0, green: light.1, blue: light.2)
        #endif
    }
}

// MARK: - Shared styles

extension View {
    /// Standard raised card: cool surface, hairline, soft shadow.
    func themedCard(corner: CGFloat = Theme.cardCorner) -> some View {
        self
            .background(Theme.card, in: RoundedRectangle(cornerRadius: corner, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .strokeBorder(Theme.rule, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
    }

    func primaryCTA(color: Color = Theme.court) -> some View {
        self
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(color, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: color.opacity(0.35), radius: 8, y: 4)
    }
}

/// A faint ruled grid, the way a coach's notebook page is ruled.
///
/// This is the one piece of ornament in the app and it is load-bearing for the
/// rebrand: a plain rounded rectangle reads as "any iOS app", while a ruled
/// panel reads as engineering paper. It is drawn with `Canvas` rather than a
/// tiled image so it stays crisp at any size and costs nothing to ship, and it
/// is clipped to the caller's shape so it never bleeds past a card edge.
struct RuledGrid: View {
    var spacing: CGFloat = 14
    var opacity: Double = 0.07
    var lineWidth: CGFloat = 0.5

    var body: some View {
        Canvas { context, size in
            var path = Path()
            var x: CGFloat = spacing
            while x < size.width {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                x += spacing
            }
            var y: CGFloat = spacing
            while y < size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += spacing
            }
            context.stroke(path, with: .color(Theme.grid.opacity(opacity)), lineWidth: lineWidth)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

extension View {
    /// Overlays `RuledGrid` inside a rounded rect, for notebook surfaces.
    func ruledGrid(corner: CGFloat = Theme.cardCorner,
                       spacing: CGFloat = 14,
                       opacity: Double = 0.07) -> some View {
        overlay(
            RuledGrid(spacing: spacing, opacity: opacity)
                .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        )
    }
}

/// The thin accent rule used as a section divider and under the onboarding
/// progress. A gradient from `court` to `ball`, i.e. the two ends of the
/// palette, so a 2pt line still carries the brand.
struct AccentRule: View {
    var height: CGFloat = 3
    var progress: Double = 1

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.rule)
                Capsule()
                    .fill(LinearGradient(
                        colors: [Theme.court, Theme.ball],
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .frame(width: max(0, min(1, progress)) * geo.size.width)
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

/// Press-scale feedback for card-shaped buttons.
struct PressableCardStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Haptics

/// Main-actor isolated on purpose: `UIFeedbackGenerator` and its subclasses are
/// main-actor types, and every caller here is a SwiftUI view already on the main
/// actor. Leaving these nonisolated is what produced the Swift 6 actor-isolation
/// warnings, and the warnings were right.
@MainActor
enum Haptics {
    enum Impact { case soft, light, rigid, heavy }

    /// Settings gate: reads the same key AppSettings writes, defaulting on.
    private static var enabled: Bool {
        UserDefaults.standard.object(forKey: "settings.haptics") as? Bool ?? true
    }

    static func impact(_ style: Impact, intensity: CGFloat = 1.0) {
        #if canImport(UIKit)
        guard enabled else { return }
        let uiStyle: UIImpactFeedbackGenerator.FeedbackStyle
        switch style {
        case .soft: uiStyle = .soft
        case .light: uiStyle = .light
        case .rigid: uiStyle = .rigid
        case .heavy: uiStyle = .heavy
        }
        UIImpactFeedbackGenerator(style: uiStyle).impactOccurred(intensity: intensity)
        #endif
    }

    static func success() {
        #if canImport(UIKit)
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }

    static func error() {
        #if canImport(UIKit)
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        #endif
    }

    /// Grading haptics have to feel like OPPOSITES in the hand, not like two
    /// versions of the same buzz. Apple's `.success` and `.error` notification
    /// patterns are both stutters and are easy to confuse mid-drill, so:
    /// right = a crisp light tap rising into the success chime; wrong = a
    /// single dull heavy thud, no chime, nothing bright about it.
    static func correctAnswer() {
        #if canImport(UIKit)
        guard enabled else { return }
        impact(.light, intensity: 0.75)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 70_000_000)
            success()
        }
        #endif
    }

    static func wrongAnswer() {
        #if canImport(UIKit)
        guard enabled else { return }
        impact(.heavy, intensity: 0.85)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 110_000_000)
            impact(.heavy, intensity: 0.45)
        }
        #endif
    }
}
