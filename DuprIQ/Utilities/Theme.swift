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

    // MARK: Interface
    //
    // The app is one dark room: the court is played under lights, and every
    // screen around it is the same night. There is no light theme to keep in
    // step with the render.

    static let background = Color(red: 0.031, green: 0.063, blue: 0.071)
    static let card = Color(red: 0.067, green: 0.110, blue: 0.122)
    static let rule = Color(white: 1, opacity: 0.10)

    /// The primary action. Deep enough to carry white text at AA.
    static let court = Color(red: 0.067, green: 0.447, blue: 0.522)
    /// Links and highlights on the dark background.
    static let courtLight = Color(red: 0.478, green: 0.827, blue: 0.898)
    static let opticInk = Color(red: 0.847, green: 0.933, blue: 0.353)
    static let gold = Color(red: 0.902, green: 0.757, blue: 0.392)

    static let ink = Color(white: 0.96)
    static let inkSecondary = Color(white: 0.72)
    static let inkTertiary = Color(white: 0.58)

    static let rightGreen = Color(red: 0.290, green: 0.851, blue: 0.576)
    static let wrongRed = Color(red: 1.0, green: 0.451, blue: 0.435)

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

/// The gold pill that marks anything behind the membership.
// MARK: - Shared styles

extension View {
    /// Keeps scrollable content clear of RootView's floating tab bar.
    ///
    /// A tab bar remains visible while a NavigationStack pushes most of the
    /// library and settings screens. Their last row is still actionable, but
    /// without this inset it sits underneath the bar instead of above it.
    func primaryCTA(color: Color = Theme.court) -> some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        return self
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(color, in: shape)
            .contentShape(shape)
            .shadow(color: color.opacity(0.35), radius: 8, y: 4)
    }
}

/// The thin accent rule used as a section divider and under the onboarding
/// progress. A gradient from the court teal to the optic ball, i.e. the two
/// ends of the new palette, so a 3pt line still carries the brand.
struct PressableCTAStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .brightness(configuration.isPressed ? -0.06 : 0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
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

extension View {
    /// A form sheet on a 13-inch iPad cuts "Your game" off after six rows and
    /// hides the paywall's third plan; page sizing gives both the screen they
    /// need. iPhone is unchanged.
    @ViewBuilder
    func pageSizedOnIPad() -> some View {
        if #available(iOS 18.0, *) {
            presentationSizing(.page)
        } else {
            self
        }
    }
}
