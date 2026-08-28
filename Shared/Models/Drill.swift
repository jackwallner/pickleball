import Foundation

/// A two-option self-test on a card's front ("Drop" / "Drive"). Answering
/// flips the card and grades the pick before the explanation lands.
struct CardChoice: Sendable {
    let options: [String]
    let answerIndex: Int

    init(_ first: String, _ second: String, answerIndex: Int) {
        options = [first, second]
        self.answerIndex = answerIndex
    }
}

struct Flashcard: Identifiable, Sendable {
    let id: String
    let frontTitle: String
    let givens: [Given]
    let frontSubtitle: String?
    let backTitle: String
    let backBody: String
    /// The principle to file this under. Shown on the back so every card
    /// teaches the system alongside the fact.
    let principle: String?
    let choice: CardChoice?

    init(id: String, frontTitle: String, givens: [Given] = [], frontSubtitle: String? = nil,
         backTitle: String, backBody: String, principle: String? = nil,
         choice: CardChoice? = nil) {
        self.id = id
        self.frontTitle = frontTitle
        self.givens = givens
        self.frontSubtitle = frontSubtitle
        self.backTitle = backTitle
        self.backBody = backBody
        self.principle = principle
        self.choice = choice
    }
}

struct QuizQuestion: Identifiable, Sendable {
    let id: String
    let prompt: String
    let givens: [Given]
    let choices: [String]
    let answerIndex: Int
    let explanation: String
    let principle: String?

    init(id: String, prompt: String, givens: [Given] = [], choices: [String],
         answerIndex: Int, explanation: String, principle: String? = nil) {
        self.id = id
        self.prompt = prompt
        self.givens = givens
        self.choices = choices
        self.answerIndex = answerIndex
        self.explanation = explanation
        self.principle = principle
    }
}

/// "Which principle governs this?" Naming the family before choosing the shot
/// is the skill that transfers to a situation the drills never showed you, so
/// this is a first-class drill and not a warm-up.
struct PrincipleMatchQuestion: Identifiable, Sendable {
    let id: String
    let scenario: String
    let choices: [Principle]
    let answer: Principle
    let explanation: String
}

/// A named shot-selection mistake: the reasoning error that produces one
/// specific wrong pick.
///
/// Every distractor an authored question offers is already the shot you choose
/// if you are making one common error. Writing that error down makes three
/// things possible that a bare wrong answer cannot do: the explanation can name
/// what the player actually did, the app can count which errors they keep
/// making, and Fix My Mistakes can put up a NEW position that sets the same
/// trap instead of replaying a question they now remember the answer to.
struct MistakePattern: Hashable, Codable, Sendable {
    /// Stable key. Persisted, so renaming one resets that tally.
    let id: String
    /// `RallyPhase.rawValue` this pattern belongs to, so a targeted follow-up
    /// position can be generated from the right phase.
    let phase: String
    /// Second person, past tense, no scolding: "You drove a ball that was
    /// below the net." This is read immediately after a miss.
    let summary: String
}

/// A worked read: a real position, the shot, and the steps that got there.
///
/// The steps matter as much as the answer. A player who misses the ORDER of the
/// read (height first, then who is set, then where the seam is) misses every
/// position of that shape, and a paragraph of explanation hides which step they
/// skipped.
struct WorkedRead: Identifiable, Sendable {
    let id: String
    let situation: String
    /// The position drawn above the question. This is the pickleball reason the
    /// worked drill exists at all: the diagram IS the given.
    let position: RallyPosition
    /// The choices shown, already formatted (e.g. "Third shot drop, cross-court kitchen").
    let choices: [String]
    let answerIndex: Int
    /// Each step of the read as one line, in order.
    let steps: [String]
    let principle: String
    /// Choice label to the mistake that produces it. Distractors only; a label
    /// absent from this map is either the answer or a padded neighbour that no
    /// named mistake happens to land on.
    var mistakes: [String: MistakePattern] = [:]
}

enum DrillKind: Sendable {
    case flashcards([Flashcard])
    case quiz([QuizQuestion])
    case principleMatch([PrincipleMatchQuestion])
    case worked([WorkedRead])

    var itemCount: Int {
        switch self {
        case .flashcards(let cards): return cards.count
        case .quiz(let questions): return questions.count
        case .principleMatch(let questions): return questions.count
        case .worked(let reads): return reads.count
        }
    }
}

struct Drill: Identifiable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let kind: DrillKind
    /// Extra practice sets inside an otherwise-free room: same mechanics, more
    /// original questions, locked behind DUPR IQ Pro. Nothing that was free
    /// became paid; these are additions.
    let isPlus: Bool

    init(id: String, title: String, subtitle: String, kind: DrillKind, isPlus: Bool = false) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.kind = kind
        self.isPlus = isPlus
    }
}

struct Room: Identifiable, Sendable {
    let id: String
    let name: String
    let tagline: String
    let icon: String
    /// A free room still opens for everyone; individual `isPlus` drills inside
    /// it are the locked extras. A non-free room is locked whole.
    let isFree: Bool
    let drills: [Drill]

    /// Drills a member unlocks here: the whole room if it's paid, otherwise
    /// just the extra sets.
    var plusDrillCount: Int {
        isFree ? drills.filter(\.isPlus).count : drills.count
    }

    func isLocked(_ drill: Drill, isMember: Bool) -> Bool {
        guard !isMember else { return false }
        return !isFree || drill.isPlus
    }
}

extension PrincipleMatchQuestion {
    /// Principle match runs through the standard quiz view. The choices are
    /// principle short names and the explanation gains the tag, so the reader
    /// always leaves knowing where the idea files.
    var asQuizQuestion: QuizQuestion {
        QuizQuestion(
            id: id,
            prompt: scenario,
            choices: choices.map(\.shortName),
            answerIndex: choices.firstIndex(of: answer) ?? 0,
            explanation: explanation,
            principle: answer.tag
        )
    }
}
