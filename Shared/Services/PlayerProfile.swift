import Foundation

/// Where a player says they are. Deliberately self-described rather than
/// derived from a DUPR number: the app is not affiliated with Dynamic Universal
/// Pickleball Rating and must never look like it is reporting or asking for an
/// official one.
enum ExperienceLevel: String, CaseIterable, Identifiable, Sendable {
    case new
    case rec
    case improving
    case competitive
    case coaching

    var id: String { rawValue }

    var title: String {
        switch self {
        case .new: return "Just started"
        case .rec: return "Rec player"
        case .improving: return "Working on my game"
        case .competitive: return "Playing tournaments"
        case .coaching: return "Teaching others"
        }
    }

    var detail: String {
        switch self {
        case .new: return "Still learning the rules and the court"
        case .rec: return "Play socially, want to stop losing the same rallies"
        case .improving: return "Solid strokes, want the decisions to catch up"
        case .competitive: return "Match play, and the margins decide it"
        case .coaching: return "Want the system stated so you can teach it"
        }
    }

    var icon: String {
        switch self {
        case .new: return "sportscourt.fill"
        case .rec: return "figure.pickleball"
        case .improving: return "chart.line.uptrend.xyaxis"
        case .competitive: return "trophy.fill"
        case .coaching: return "person.2.fill"
        }
    }

    /// What this app is actually going to do for them. Concrete, and honest
    /// about the fact that it drills decisions rather than strokes.
    var emphasis: String {
        switch self {
        case .new:
            return "Start in Court Basics. The rules that decide close rallies are not the ones people explain to you on court."
        case .rec:
            return "The Kitchen Game is where rec rallies are lost. Most of them go to whoever attacks a low ball first."
        case .improving:
            return "Third Shot & Transition is the room. The drop-or-drive read is worth more points than any stroke change."
        case .competitive:
            return "Run Endless Practice on mixed phases. The generator never repeats, so you are drilling the read rather than the picture."
        case .coaching:
            return "Every answer names the principle it came from, so the app gives you shared vocabulary rather than just a verdict."
        }
    }
}

/// What the player told us about themselves, and what they asked us to
/// prioritise.
///
/// Deliberately small. The shell this was ported from carried a licence track, a
/// jurisdiction, a code-book edition and an exam date because all four change
/// what a candidate should study. Pickleball has one useful axis (how much of
/// the decision-making is already automatic) plus an optional next-match date,
/// and inventing more questions to fill an onboarding flow would be asking for
/// answers the app cannot act on.
@MainActor
final class PlayerProfile: ObservableObject {
    static let shared = PlayerProfile()

    private enum Keys {
        static let level = "player.level"
        static let hasSelectedLevel = "player.hasSelectedLevel"
        static let matchDate = "player.matchDate"
        static let setupComplete = "player.setupComplete"
        static let focusAreas = "player.focusAreas"
        static let dailyGoal = "player.dailyGoal"
    }

    private let defaults: UserDefaults

    @Published var level: ExperienceLevel {
        didSet { defaults.set(level.rawValue, forKey: Keys.level) }
    }

    /// The next match or tournament, if they named one. Drives the Match
    /// Warm-Up card on the lobby.
    @Published var matchDate: Date? {
        didSet {
            if let matchDate {
                defaults.set(matchDate, forKey: Keys.matchDate)
            } else {
                defaults.removeObject(forKey: Keys.matchDate)
            }
        }
    }

    /// Room ids the player asked to prioritise. Empty means "no preference",
    /// which is a real answer and not a missing one.
    @Published var focusAreas: Set<String> {
        didSet { defaults.set(Array(focusAreas).sorted(), forKey: Keys.focusAreas) }
    }

    /// Balls a day the player is aiming for.
    @Published var dailyGoal: Int {
        didSet { defaults.set(dailyGoal, forKey: Keys.dailyGoal) }
    }

    @Published private(set) var hasSelectedLevel: Bool {
        didSet { defaults.set(hasSelectedLevel, forKey: Keys.hasSelectedLevel) }
    }

    @Published private(set) var setupComplete: Bool {
        didSet { defaults.set(setupComplete, forKey: Keys.setupComplete) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        level = ExperienceLevel(rawValue: defaults.string(forKey: Keys.level) ?? "") ?? .rec
        matchDate = defaults.object(forKey: Keys.matchDate) as? Date
        focusAreas = Set(defaults.stringArray(forKey: Keys.focusAreas) ?? [])
        dailyGoal = defaults.object(forKey: Keys.dailyGoal) as? Int ?? 15
        hasSelectedLevel = defaults.bool(forKey: Keys.hasSelectedLevel)
        setupComplete = defaults.bool(forKey: Keys.setupComplete)
    }

    func selectLevel(_ level: ExperienceLevel) {
        self.level = level
        hasSelectedLevel = true
    }

    func markSetupComplete() { setupComplete = true }

    /// Whole days until the next match, or `nil` if none is set or it has
    /// passed. Counted in calendar days so "tomorrow" reads as 1 regardless of
    /// the hour it was entered at.
    var daysUntilMatch: Int? {
        guard let matchDate else { return nil }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let target = calendar.startOfDay(for: matchDate)
        guard let days = calendar.dateComponents([.day], from: today, to: target).day, days >= 0 else {
            return nil
        }
        return days
    }

    /// One line for the lobby card.
    var targetSummary: String {
        guard let days = daysUntilMatch else { return level.title }
        if days == 0 { return "You play today" }
        if days == 1 { return "You play tomorrow" }
        return "\(days) days until you play"
    }

    var levelSummary: String { level.title }

    /// A daily target that scales with how close the match is. Not a promise,
    /// and the lobby words it as a target rather than a requirement.
    var suggestedDailyBalls: Int {
        guard let days = daysUntilMatch else { return dailyGoal }
        switch days {
        case 0...2: return max(dailyGoal, 25)
        case 3...7: return max(dailyGoal, 20)
        default: return dailyGoal
        }
    }

    func resetForTesting() {
        level = .rec
        matchDate = nil
        focusAreas = []
        dailyGoal = 15
        hasSelectedLevel = false
        setupComplete = false
    }
}
