import Foundation

extension RallyPosition {

    /// The whole decision, spoken.
    ///
    /// The task is reading a court, so a description that stops at "opponents
    /// at the kitchen" hides the exact thing being graded: which opponent is
    /// short, how wide the seam between them is, where the contact sits
    /// relative to the middle, and how high the ball is. Every one of those is
    /// a fact a sighted player reads off the render, so every one of them has
    /// to be said out loud.
    ///
    /// It lives on the model rather than inside a view because two views draw
    /// this position now (the first-person court and the overhead explanation)
    /// and a rally that describes itself differently depending on which one is
    /// on screen would be a bug nobody would ever see.
    func spokenDescription(highlight: OpponentSide? = nil) -> String {
        var parts: [String] = [
            phase.title + ".",
            "You are \(yourZone.label.lowercased()), hitting \(contactSideLabel).",
            "Your partner is \(partnerZone.label.lowercased()).",
            "Left opponent \(opponentLeftZone.label.lowercased()), "
                + "right opponent \(opponentRightZone.label.lowercased()).",
        ]
        if let lagging = laggingOpponentSide {
            parts.append("\(lagging.label.capitalizedFirst) has not reached the line.")
        } else if opponentsBothAtKitchen {
            parts.append("Both opponents are set at the line.")
        }
        parts.append(
            isMiddleOpen
                ? "They are about \(Int(opponentSpread.rounded())) feet apart, so the middle is open."
                : "They are about \(Int(opponentSpread.rounded())) feet apart, covering the middle."
        )
        parts.append("The ball is \(ballHeight.label.lowercased()).")
        if let highlight {
            parts.append("The answer targets \(highlight.label), marked \(highlight.marker).")
        }
        parts.append("Score, \(scoreLine).")
        return parts.joined(separator: " ")
    }
}
