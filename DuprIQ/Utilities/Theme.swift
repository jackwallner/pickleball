import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// The design system, taken from a pickleball court rather than from paper.
///
/// The shell arrived here through `~/mahj` and `~/electrician`, and it brought
/// their look with it: cool drawing-paper grey, navy, and a faint ruled grid
/// meant to read as engineering notebook stock. That is a studying surface, and
/// this app is not a study aid. Everything below is named after a thing you can
/// point at on a court under lights, and the 3D scene in `CourtScene` draws
/// from the same `Surface` constants, so the rendered court and the chrome
/// around it can never drift apart.
///
/// Light mode is an outdoor court on a bright morning: warm apron, saturated
/// paint. Dark mode is an indoor club at night, which is the mode the first
/// person view was drawn for.
enum Theme {
    // MARK: The court itself
    //
    // These are the physical colors of the surface, shared with the 3D scene.
    // Nothing else in the app is allowed to invent a court color.

    enum Surface {
        /// The painted playing area, the blue-teal of a tournament surface.
        static let play = Color(red: 0.078, green: 0.310, blue: 0.404)
        /// The non-volley zone, in the clay terracotta it is nearly always
        /// painted so it reads as a different place at a glance.
        static let kitchen = Color(red: 0.647, green: 0.298, blue: 0.192)
        /// The apron outside the lines.
        static let apron = Color(red: 0.086, green: 0.243, blue: 0.180)
        /// Line paint.
        static let line = Color(red: 0.949, green: 0.965, blue: 0.961)
        /// The net's mesh and its white tape.
        ///
        /// Grey-green, not near-black. At the distance the opponents stand,
        /// black cords closed up into a solid grid across their legs, which is
        /// the exact failure the mesh exists to avoid: you are supposed to look
        /// THROUGH a net.
        static let netMesh = Color(red: 0.416, green: 0.463, blue: 0.459)
        static let netTape = Color(red: 0.961, green: 0.973, blue: 0.973)
        /// An optic ball. The single brightest object on a court, which is why
        /// it is also the app's energy accent below.
        static let ball = Color(red: 0.847, green: 0.933, blue: 0.180)
    }

    // MARK: Brand
    //
    // Court accents are semantic: teal is the court and the primary action,
    // deep green is the soft game, fence grey is the walk to the line, and
    // terracotta (the kitchen paint) is pressure.

    /// Court teal. Primary actions, progress, selected states. Dark enough in
    /// light mode to carry white text on the fill and to pass AA as foreground.
    static let court = Color(light: (0.043, 0.325, 0.420), dark: (0.416, 0.784, 0.867))
    /// Kitchen terracotta. Pressure, attack, the room about hitting hard.
    static let kitchen = Color(light: (0.596, 0.278, 0.157), dark: (0.898, 0.573, 0.427))
    /// Deep surround green. The soft game.
    static let apron = Color(light: (0.086, 0.376, 0.259), dark: (0.396, 0.784, 0.573))
    /// Fence grey-green. Transition, the least loud accent.
    static let slate = Color(light: (0.259, 0.353, 0.373), dark: (0.612, 0.729, 0.749))
    /// Gold. Locks, "best value", membership highlights.
    static let gold = Color(light: (0.612, 0.463, 0.098), dark: (0.878, 0.729, 0.353))

    /// Optic ball yellow-green. A FILL ONLY: streaks, celebration, the shot
    /// clock, the live ball. Never use it as text on a light background, it
    /// cannot pass contrast there. Use `opticInk` for that.
    static let optic = Color(light: (0.788, 0.867, 0.129), dark: (0.847, 0.933, 0.250))
    /// The text-safe darkening of `optic`, for a label that has to say the same
    /// thing the yellow fill says.
    static let opticInk = Color(light: (0.318, 0.365, 0.020), dark: (0.808, 0.898, 0.353))

    /// The old name for the energy accent, kept pointing at the terracotta so
    /// nothing that referenced it silently turns a different hue.
    static let ball = kitchen

    // MARK: Surfaces

    /// Court apron in daylight, club floor at night. Never pure white or black.
    static let background = Color(light: (0.961, 0.957, 0.941), dark: (0.043, 0.063, 0.067))
    /// Raised card surface.
    static let card = Color(light: (1.0, 0.998, 0.992), dark: (0.086, 0.114, 0.122))
    /// Slightly sunken surface for wells inside cards.
    static let well = Color(light: (0.925, 0.922, 0.902), dark: (0.063, 0.086, 0.094))
    /// Hairline stroke on cards.
    static let rule = Color(light: (0.839, 0.831, 0.804), dark: (0.180, 0.227, 0.239))

    // MARK: Ink

    // Contrast is not a style knob here. This app's readers skew 50+ and read
    // it on a couch in bad light, and tertiary ink carries the money disclosure
    // and the swipe instructions. Every level below clears WCAG AA (4.5:1) on
    // both backgrounds. Re-check with a contrast calculator before warming the
    // apron any further.
    static let ink = Color(light: (0.086, 0.106, 0.106), dark: (0.941, 0.957, 0.949))
    /// 6.7:1 light / 7.6:1 dark.
    static let inkSecondary = Color(light: (0.318, 0.341, 0.341), dark: (0.702, 0.745, 0.737))
    /// 4.7:1 light / 5.8:1 dark.
    static let inkTertiary = Color(light: (0.396, 0.420, 0.420), dark: (0.596, 0.647, 0.639))

    // MARK: Panels and grading

    /// The inset panel stock: a court-tinted surface for a chip row or a worked
    /// read. It replaces the notebook "worksheet" the shell arrived with, which
    /// is the single most textbook-looking thing the port brought over.
    static let panel = Color(light: (0.976, 0.980, 0.973), dark: (0.118, 0.153, 0.161))
    static let panelEdge = Color(light: (0.812, 0.831, 0.816), dark: (0.208, 0.263, 0.271))

    /// Grading colors. Deliberately not `court`/`kitchen`/`apron`: right and
    /// wrong have to read as a verdict, not as brand accents used elsewhere on
    /// the screen. `rightGreen` is kept bright and cool so it can never be
    /// mistaken for the deep `apron` accent.
    static let rightGreen = Color(light: (0.055, 0.514, 0.310), dark: (0.290, 0.851, 0.576))
    static let wrongRed = Color(light: (0.702, 0.145, 0.153), dark: (1.0, 0.451, 0.435))

    // MARK: Type

    /// Display type for titles. Heavy condensed sans, the lettering of a
    /// scoreboard and a tournament draw sheet. `.width` needs iOS 16; the
    /// fallback keeps the weight.
    static func display(_ size: CGFloat, weight: Font.Weight = .heavy) -> Font {
        if #available(iOS 16.0, *) {
            return .system(size: size, weight: weight).width(.condensed)
        }
        return .system(size: size, weight: weight)
    }

    /// Numbers read as instrument readings, not prose: scores, percentages, the
    /// shot clock and ball counts all use this so columns line up and a value
    /// never reflows differently from the one above it.
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

/// Court identity: each court keeps its own accent so the four doors feel like
/// four places, not four list rows.
extension Court {
    var accent: Color {
        switch id {
        case DrillLibrary.basicsCourtID: return Theme.court
        case DrillLibrary.kitchenCourtID: return Theme.apron
        case DrillLibrary.transitionCourtID: return Theme.slate
        // The pressure court. Copper, the palette's energy accent, because it is
        // the court about hitting the ball hard and surviving one hit hard at you.
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
    /// Keeps scrollable content clear of RootView's floating tab bar.
    ///
    /// A tab bar remains visible while a NavigationStack pushes most of the
    /// library and settings screens. Their last row is still actionable, but
    /// without this inset it sits underneath the bar instead of above it.
    func tabBarClearance(_ height: CGFloat = 96) -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: height)
        }
    }

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

/// The thin accent rule used as a section divider and under the onboarding
/// progress. A gradient from the court teal to the optic ball, i.e. the two
/// ends of the new palette, so a 3pt line still carries the brand.
struct AccentRule: View {
    var height: CGFloat = 3
    var progress: Double = 1

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.rule)
                Capsule()
                    .fill(LinearGradient(
                        colors: [Theme.court, Theme.optic],
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
