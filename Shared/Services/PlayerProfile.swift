import Foundation

/// Where a player says they are. Self-described on purpose: the app is not
/// affiliated with any rating system and never asks for or reports a rating.
enum ExperienceLevel: String, CaseIterable, Identifiable, Sendable {
    case new
    case rec
    case improving
    case competitive

    var id: String { rawValue }

    var title: String {
        switch self {
        case .new: return "Just started"
        case .rec: return "Rec player"
        case .improving: return "Working on my game"
        case .competitive: return "Playing tournaments"
        }
    }

    var detail: String {
        switch self {
        case .new: return "Still learning where to stand"
        case .rec: return "Play socially, lose the same rallies"
        case .improving: return "Solid strokes, decisions lag behind"
        case .competitive: return "Match play, the margins decide it"
        }
    }

    /// Where the first focus points come from, before the app has measured
    /// anything. Each level starts on the phase its rallies are usually lost in.
    var starterPhases: [RallyPhase] {
        switch self {
        case .new: return [.serveReturn, .dinkRally]
        case .rec: return [.dinkRally, .attack]
        case .improving: return [.thirdShot, .transition]
        case .competitive: return [.transition, .defense]
        }
    }
}

/// Which half of the court the player usually covers.
enum CourtHalf: String, CaseIterable, Identifiable, Sendable {
    case left, right, either

    var id: String { rawValue }

    var title: String {
        switch self {
        case .left: return "Left side"
        case .right: return "Right side"
        case .either: return "Either side"
        }
    }

    var detail: String {
        switch self {
        case .left: return "Positions put you on the left half"
        case .right: return "Positions put you on the right half"
        case .either: return "A mix of both halves"
        }
    }
}

/// What the player told us in onboarding. Every answer here changes what the
/// court generates; nothing is asked that the app cannot act on.
@MainActor
final class PlayerProfile: ObservableObject {
    static let shared = PlayerProfile()

    private enum Keys {
        static let level = "player.level"
        static let half = "player.half"
        static let setupComplete = "player.setupComplete"
    }

    private let defaults: UserDefaults

    @Published var level: ExperienceLevel {
        didSet { defaults.set(level.rawValue, forKey: Keys.level) }
    }

    @Published var half: CourtHalf {
        didSet { defaults.set(half.rawValue, forKey: Keys.half) }
    }

    @Published private(set) var setupComplete: Bool {
        didSet { defaults.set(setupComplete, forKey: Keys.setupComplete) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        level = ExperienceLevel(rawValue: defaults.string(forKey: Keys.level) ?? "") ?? .rec
        half = CourtHalf(rawValue: defaults.string(forKey: Keys.half) ?? "") ?? .either
        setupComplete = defaults.bool(forKey: Keys.setupComplete)
    }

    func markSetupComplete() { setupComplete = true }

    func resetForTesting() {
        level = .rec
        half = .either
        setupComplete = false
    }
}
