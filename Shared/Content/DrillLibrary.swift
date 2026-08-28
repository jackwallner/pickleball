import Foundation

/// The room structure. Two free rooms open the app, two paid rooms carry the
/// parts of the game that actually decide rallies at 3.5 and up.
///
/// Room ids are referenced by `RallyPhase.roomID` and by the stats breakdown,
/// so renaming one means updating both.
enum DrillLibrary {

    static let basicsRoomID = "basics-room"
    static let kitchenRoomID = "kitchen-room"
    static let transitionRoomID = "transition-room"
    static let pressureRoomID = "pressure-room"

    static let rooms: [Room] = [
        Room(
            id: basicsRoomID,
            name: "Court Basics",
            tagline: "The rules and the vocabulary the rest of it rests on",
            icon: "sportscourt.fill",
            isFree: true,
            drills: [
                Drill(
                    id: "court-cards",
                    title: "Read the Court",
                    subtitle: "Flashcards: the kitchen, the zones, and the words coaches use",
                    kind: .flashcards(CourtBasicsContent.courtCards)
                ),
                Drill(
                    id: "rules-quiz",
                    title: "Rules That Cost Points",
                    subtitle: "Quiz: the non-volley zone, the two-bounce rule, and serving",
                    kind: .quiz(CourtBasicsContent.rulesQuiz)
                ),
                Drill(
                    id: "principle-cards",
                    title: "The Nine Principles",
                    subtitle: "Flashcards: every principle the app answers with, and its tell",
                    kind: .flashcards(PrincipleContent.principleCards)
                ),
                Drill(
                    id: "principle-match",
                    title: "Which Principle?",
                    subtitle: "Read a situation, name the principle, before you pick a shot",
                    kind: .principleMatch(PrincipleContent.principleMatch)
                ),
                Drill(
                    id: "plus-basics-extras",
                    title: "Rules That Cost Points: Extra Reps",
                    subtitle: "Four more on the kitchen, faults, and the score call",
                    kind: .quiz(PlusContent.basicsExtras),
                    isPlus: true
                ),
                Drill(
                    id: "plus-principle-extras",
                    title: "Which Principle? Extra Reps",
                    subtitle: "The situations where two principles look like they collide",
                    kind: .principleMatch(PlusContent.principleExtras),
                    isPlus: true
                ),
            ]
        ),
        Room(
            id: kitchenRoomID,
            name: "The Kitchen Game",
            tagline: "Nobody wins from the baseline",
            icon: "hand.tap.fill",
            isFree: true,
            drills: [
                Drill(
                    id: "dink-cards",
                    title: "What Makes a Ball Safe",
                    subtitle: "Flashcards: net height, contact point, and why soft wins",
                    kind: .flashcards(KitchenContent.dinkCards)
                ),
                Drill(
                    id: "kitchen-quiz",
                    title: "Dink Decisions",
                    subtitle: "Quiz: cross-court, middle, and when patience is the shot",
                    kind: .quiz(KitchenContent.kitchenQuiz)
                ),
                Drill(
                    id: "plus-kitchen-extras",
                    title: "Dink Decisions: Extra Reps",
                    subtitle: "Seams, the backhand target, and the ball you should let go",
                    kind: .quiz(PlusContent.kitchenExtras),
                    isPlus: true
                ),
            ]
        ),
        Room(
            id: transitionRoomID,
            name: "Third Shot & Transition",
            tagline: "The two shots that get you to the line",
            icon: "figure.walk",
            isFree: false,
            drills: [
                Drill(
                    id: "third-shot-cards",
                    title: "Drop or Drive",
                    subtitle: "Flashcards: what each one is for, and what decides it",
                    kind: .flashcards(TransitionContent.thirdShotCards)
                ),
                Drill(
                    id: "third-shot-quiz",
                    title: "Third Shot Check",
                    subtitle: "Quiz: reading their feet before you choose the shape",
                    kind: .quiz(TransitionContent.thirdShotQuiz)
                ),
                Drill(
                    id: "worked-reads",
                    title: "Worked Reads",
                    subtitle: "Six real positions, read step by step",
                    kind: .worked(TransitionContent.workedReads)
                ),
            ]
        ),
        Room(
            id: pressureRoomID,
            name: "Attack & Defense",
            tagline: "Recognising the ball you can finish, and surviving the one you can't",
            icon: "bolt.fill",
            isFree: false,
            drills: [
                Drill(
                    id: "attack-cards",
                    title: "The Ball You Can Finish",
                    subtitle: "Flashcards: height, angle, and where a put-away goes",
                    kind: .flashcards(ProContent.attackCards)
                ),
                Drill(
                    id: "attack-quiz",
                    title: "Attack Check",
                    subtitle: "Quiz: speed-ups worth taking and the ones that lose the point",
                    kind: .quiz(ProContent.attackQuiz)
                ),
                Drill(
                    id: "defense-cards",
                    title: "Getting Out of Trouble",
                    subtitle: "Flashcards: the reset, the block, and the shot to never hit",
                    kind: .flashcards(ProContent.defenseCards)
                ),
                Drill(
                    id: "defense-quiz",
                    title: "Defense Check",
                    subtitle: "Quiz: what to do with a ball at your shoetops",
                    kind: .quiz(ProContent.defenseQuiz)
                ),
            ]
        ),
    ]

    /// The room a given id belongs to, for stats labelling.
    static func room(id: String) -> Room? {
        rooms.first { $0.id == id }
    }

    /// The room that owns a drill, for the per-room accuracy breakdown.
    static func roomID(forDrillID drillID: String) -> String {
        rooms.first { room in
            room.drills.contains { $0.id == drillID }
        }?.id ?? basicsRoomID
    }

    /// The phase a room's authored items train, when the room is about one
    /// phase. `nil` for rooms that span several, which is what keeps a
    /// vocabulary question out of the transition accuracy number.
    static func phase(forRoomID roomID: String) -> RallyPhase? {
        switch roomID {
        case kitchenRoomID: return .dinkRally
        default: return nil
        }
    }
}
