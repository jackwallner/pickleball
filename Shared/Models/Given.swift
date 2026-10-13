import Foundation

/// One labelled condition above a question: the "given" line that tells you
/// what the situation is before it asks what you would do.
///
/// A generated drill draws the whole situation as a court, so it needs none of
/// these. An authored question usually does not have a full four-player
/// position behind it ("the score is 9-8, you are serving, what changes?"), and
/// baking those conditions into prompt prose makes them easy to skim past.
/// Keeping them structured is what lets the renderer lay them out identically
/// every time and lets VoiceOver read them as a list rather than a sentence.
struct Given: Hashable, Codable, Sendable, Identifiable {
    /// What the value is. Short: this renders as a chip caption.
    let label: String
    /// The value itself, already formatted for display.
    let value: String
    /// Optional unit shown smaller after the value.
    let unit: String?

    var id: String { "\(label)|\(value)|\(unit ?? "")" }

    init(_ label: String, _ value: String, unit: String? = nil) {
        self.label = label
        self.value = value
        self.unit = unit
    }

    // Shorthand for the conditions that recur across authored questions.

    static func score(_ yours: Int, _ theirs: Int, serving: Bool) -> Given {
        Given("Score", "\(yours)-\(theirs)", unit: serving ? "serving" : "receiving")
    }

    static func ballHeight(_ height: BallHeight) -> Given {
        Given("Ball", height.label)
    }

    static func you(_ zone: CourtZone) -> Given {
        Given("You", zone.label)
    }

    static func partner(_ zone: CourtZone) -> Given {
        Given("Partner", zone.label)
    }

    static func opponents(_ description: String) -> Given {
        Given("Opponents", description)
    }

    static func phase(_ phase: RallyPhase) -> Given {
        Given("Phase", phase.title)
    }

    static func side(_ description: String) -> Given {
        Given("Contact", description)
    }

    var spokenLabel: String {
        if let unit { return "\(label): \(value) \(unit)" }
        return "\(label): \(value)"
    }
}
