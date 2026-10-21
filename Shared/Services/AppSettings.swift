import SwiftUI

/// The two things a player can tune: the decision timer and haptics.
@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    /// Optional pressure for players who already understand the court read.
    /// New players need time to learn what the ball, feet and rings mean
    /// before speed is useful, so the court starts untimed.
    enum ShotClock: String, CaseIterable, Identifiable {
        case off, relaxed, match, tournament

        var id: String { rawValue }

        var seconds: Double? {
            switch self {
            case .tournament: return 3
            case .match: return 5
            case .relaxed: return 9
            case .off: return nil
            }
        }

        var displayName: String {
            switch self {
            case .off: return "Off"
            case .relaxed: return "Learning pace (9s)"
            case .match: return "Game pace (5s)"
            case .tournament: return "Fast reads (3s)"
            }
        }
    }

    private enum Keys {
        static let haptics = "settings.haptics"
        static let shotClock = "settings.shotClock"
    }

    private let defaults: UserDefaults

    @Published var hapticsEnabled: Bool {
        didSet { defaults.set(hapticsEnabled, forKey: Keys.haptics) }
    }

    @Published var shotClock: ShotClock {
        didSet { defaults.set(shotClock.rawValue, forKey: Keys.shotClock) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        hapticsEnabled = defaults.object(forKey: Keys.haptics) as? Bool ?? true
        shotClock = ShotClock(rawValue: defaults.string(forKey: Keys.shotClock) ?? "") ?? .off
    }

    func resetForTesting() {
        hapticsEnabled = true
        shotClock = .off
    }
}
