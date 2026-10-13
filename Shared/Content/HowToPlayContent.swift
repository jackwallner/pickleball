import Foundation

/// One page of the quick-start primer.
struct HowToPlayPage: Identifiable, Sendable {
    let id: String
    let icon: String
    let title: String
    let body: String
    let givens: [Given]
    let tip: String?

    init(id: String, icon: String, title: String, body: String,
         givens: [Given] = [], tip: String? = nil) {
        self.id = id
        self.icon = icon
        self.title = title
        self.body = body
        self.givens = givens
        self.tip = tip
    }
}

/// The five-minute primer for anyone who picked "just started" in onboarding.
///
/// It explains the shape of a rally before it explains any shot, because that
/// is the part nobody tells you on a rec court and it changes what every shot
/// is for. Nothing here is stroke instruction; this app grades decisions.
enum HowToPlayContent {
    static let pages: [HowToPlayPage] = [
        HowToPlayPage(
            id: "htp-where-points-are-won",
            icon: "sportscourt.fill",
            title: "Points are won at the kitchen",
            body: "Almost nothing is won from the baseline. The team standing at the non-volley line takes the ball earlier, hits down instead of up, and gives the other team no time. Every shot in this app is graded against one question: does this get us to the line, or keep us there?",
            tip: "If a shot does not either get you forward or keep the ball unattackable, it is usually the wrong shot."
        ),
        HowToPlayPage(
            id: "htp-two-bounce",
            icon: "arrow.uturn.backward",
            title: "The serving team starts behind",
            body: "The serve must bounce, and so must the return. That means the returning team can walk to the line while the serving team is stuck at the baseline waiting for the ball to land. The whole opening of a rally is one team travelling and the other team defending the line.",
            givens: [.phase(.serveReturn)],
            tip: "As the returning team you should be at the kitchen before their third shot arrives. Most players are not."
        ),
        HowToPlayPage(
            id: "htp-attackable",
            icon: "arrow.up.and.down",
            title: "One test decides everything",
            body: "Can you make contact above the top of the net? If yes, you can hit downward and the ball stays down. If no, whatever you hit has to rise to clear the net, so it arrives at the other player somewhere they can hit down on it. Speed, spin and confidence do not change that geometry.",
            givens: [.ballHeight(.aboveNet), .ballHeight(.belowNet)],
            tip: "Check the height before you choose the shot. Choosing first and checking after is how low balls get driven."
        ),
        HowToPlayPage(
            id: "htp-third-shot",
            icon: "arrow.up.forward",
            title: "The third shot is transportation",
            body: "The serving team's third shot exists to fix the disadvantage the two-bounce rule created. Arc it into their kitchen so it lands below the net, and use the time it buys to walk in. It is not a scoring shot, and treating it as one is the most common way a serving team loses a rally it was still level in.",
            givens: [.phase(.thirdShot)],
            tip: "Drive the third only when someone has not made the line yet, or when the ball has sat up above the net."
        ),
        HowToPlayPage(
            id: "htp-feet",
            icon: "figure.walk",
            title: "Read their feet, not the ball",
            body: "Two opponents standing in different places is the most useful information on the court. A player who has not stopped moving cannot get low or get their paddle out in front, so the ball goes at their feet. Two players who have drifted apart have left a seam that neither of them owns.",
            tip: "Every ball puts you on the court looking at it. Where their feet are and how high the ball is against the net tape are not decoration; they are the question."
        ),
        HowToPlayPage(
            id: "htp-generated",
            icon: "infinity",
            title: "Why this app generates positions",
            body: "A fixed question bank is a pile you finish in a weekend, and by the second pass you are remembering pictures rather than making reads. Every position here is generated: the four players' feet, the ball height and the score are new each time, and the answer comes from the same rules engine every time. Every wrong option is a shot a real player is actually tempted by.",
            tip: "After a miss, read the steps. The step you skipped is the one that will cost you again."
        ),
        HowToPlayPage(
            id: "htp-opinion",
            icon: "quote.bubble.fill",
            title: "This is coached opinion, stated out loud",
            body: "Shot selection is not arithmetic, and anyone who tells you their answer is the only one is selling something. This app commits to one mainstream system, keep the ball unattackable, get to the kitchen, hit the player who isn't set, and names the principle behind every answer so you can argue with the reasoning rather than with a bare verdict.",
            tip: "If you disagree with an answer, look at the named principle. That is the thing to disagree with."
        ),
        HowToPlayPage(
            id: "htp-coverage",
            icon: "checklist",
            title: "What this app covers today",
            // The pages above describe how a rally works, which is easy to
            // mistake for a claim about the app's scope. Saying where the drills
            // actually go is more useful than implying a curriculum that does
            // not exist yet, and a player who finds the gap themselves after
            // paying is right to be annoyed.
            body: "Four courts: the court and the rules, the soft game at the kitchen, the third shot and the walk in, and attack and defense. On top of those the generator runs all six rally phases without limit. That is the whole of it right now, and it is deliberately the part of the game that is pure decision-making.",
            tip: "Serving strategy, stacking, singles and stroke technique are not covered. This app grades where the ball should go, not how to hit it."
        ),
    ]
}

extension HowToPlayContent {
    /// Maps the onboarding experience level to the court recommended at the end
    /// of the primer. Someone already playing tournaments does not need the
    /// rules tour; they need the court where their rallies are actually lost.
    static func recommendedCourt(forSkillLevel skillLevel: String) -> Court {
        let courtID: String
        switch ExperienceLevel(rawValue: skillLevel) {
        case .rec: courtID = DrillLibrary.kitchenCourtID
        case .improving: courtID = DrillLibrary.transitionCourtID
        case .competitive, .coaching: courtID = DrillLibrary.pressureCourtID
        case .new, .none: courtID = DrillLibrary.basicsCourtID
        }
        return DrillLibrary.courts.first { $0.id == courtID } ?? DrillLibrary.courts[0]
    }

    /// A player's focus picks win over the experience-level default: they were
    /// asked the question directly and answering it should do something.
    static func recommendedCourt(forSkillLevel skillLevel: String,
                                focusAreas: Set<String>) -> Court {
        if let focused = DrillLibrary.courts.first(where: { focusAreas.contains($0.id) }) {
            return focused
        }
        return recommendedCourt(forSkillLevel: skillLevel)
    }
}
