import Foundation

/// "Report a possible issue" on a graded question.
///
/// This app's biggest trust risk is not a crash, it is a verdict. Shot
/// selection is coached opinion, so a player who thinks an answer is wrong is
/// sometimes right and is always worth hearing. Without a route for that, their
/// only option is a one-star review saying so, which is the worst possible
/// place for the information to land, for them and for us.
///
/// So a miss gets a low-friction path to a real report, and the report carries
/// what makes it actionable without asking the player to transcribe anything:
/// the item id, the principle the answer came from, the shot the app claimed,
/// and what they picked. Everything else is their own words.
///
/// It goes out as a mailto draft for the same reason the feedback funnel does:
/// no account, no analytics endpoint, no practice data leaving the phone.
enum ContentReport {

    /// What the reader was looking at when they tapped Report.
    struct Context: Equatable, Sendable {
        let itemID: String
        let prompt: String
        let principle: String?
        let correctAnswer: String
        let selectedAnswer: String?

        init(itemID: String, prompt: String, principle: String?, correctAnswer: String, selectedAnswer: String?) {
            self.itemID = itemID
            self.prompt = prompt
            self.principle = principle
            self.correctAnswer = correctAnswer
            self.selectedAnswer = selectedAnswer
        }
    }

    /// The categories worth separating, because they route to different fixes.
    /// "I would play a different shot" is deliberately its own category and
    /// deliberately not called a bug: the app commits to one stated system, and
    /// a disagreement with that system is a different thing from an answer that
    /// contradicts it.
    enum Category: String, CaseIterable, Identifiable, Sendable {
        case wrongAnswer
        case unclearExplanation
        case coachingDisagreement
        case typo

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .wrongAnswer: return "The answer looks wrong"
            case .unclearExplanation: return "The explanation is unclear"
            case .coachingDisagreement: return "I'd play a different shot here"
            case .typo: return "Typo or formatting"
            }
        }
    }

    static func mailURL(context: Context, category: Category, appVersion: String) -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = AppStoreLinks.feedbackEmail

        var lines = [
            "",
            "",
            "----- please leave the details below -----",
            "Issue: \(category.displayName)",
            "Item: \(context.itemID)",
            "Principle: \(context.principle ?? "none")",
            "App reported: \(context.correctAnswer)",
        ]
        if let selected = context.selectedAnswer {
            lines.append("You picked: \(selected)")
        }
        lines.append("App version: \(appVersion)")
        lines.append("Question: \(context.prompt)")

        components.queryItems = [
            URLQueryItem(name: "subject", value: "DuprIQ content report: \(category.displayName)"),
            URLQueryItem(name: "body", value: lines.joined(separator: "\n")),
        ]
        return components.url
    }

    static var appVersion: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        return "\(short) (\(build))"
    }
}
