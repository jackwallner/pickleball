import SwiftUI

/// How to read the diagram, shown once on first launch and available forever
/// from the lobby and from Settings.
///
/// The product's whole task is reading four sets of feet. A player who has not
/// been told which marker is theirs, where the kitchen is, or what "above net
/// height" is deciding, is guessing at question one and will read the app as a
/// quiz rather than as coaching.
struct CourtPrimerView: View {
    static let seenKey = "onboarding.hasSeenCourtPrimer"

    let isFirstRun: Bool

    @AppStorage(CourtPrimerView.seenKey) private var hasSeenPrimer = false
    @Environment(\.dismiss) private var dismiss

    init(isFirstRun: Bool = false) {
        self.isFirstRun = isFirstRun
    }

    /// A fixed, legal example position so the legend points at something real.
    private static let example = RallyPosition(
        id: "primer", phase: .thirdShot,
        you: CourtPoint(x: 6.5, y: 3.5),
        partner: CourtPoint(x: 14, y: 4),
        opponentLeft: CourtPoint(x: 6, y: 29.6),
        opponentRight: CourtPoint(x: 14.5, y: 34.5),
        contact: CourtPoint(x: 7, y: 4.5),
        ballHeight: .belowNet,
        yourScore: 4, theirScore: 6, isServingTeam: true
    )

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Every ball is one court, seen from behind your own baseline.")
                        .font(.headline)

                    CourtDiagramView(position: Self.example)
                        .frame(maxHeight: 300)
                        .accessibilityHidden(true)

                    ForEach(Self.legend, id: \.title) { item in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: item.symbol)
                                .font(.body)
                                .foregroundStyle(item.tint)
                                .frame(width: 24)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title).font(.subheadline.weight(.semibold))
                                Text(item.detail)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }

                    Text("""
                    Four shots are offered. One of them is the answer the \
                    coaching system gives, and after you pick, the app names \
                    the principle behind it. Shot selection is coached opinion, \
                    so the principle is the thing to argue with.
                    """)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
                .padding()
            }
            .safeAreaInset(edge: .bottom) {
                Button(isFirstRun ? "Start drilling" : "Got it") {
                    hasSeenPrimer = true
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .padding()
                .background(.bar)
                .accessibilityIdentifier("primer-done")
            }
            .navigationTitle("Reading the court")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isFirstRun {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { dismiss() }
                    }
                }
            }
        }
        .onDisappear { hasSeenPrimer = true }
    }

    private struct LegendItem {
        let symbol: String
        let tint: Color
        let title: String
        let detail: String
    }

    private static let legend: [LegendItem] = [
        LegendItem(
            symbol: "circle.fill", tint: .yellow,
            title: "You are the marker labelled You",
            detail: "Bottom half of the court, always. Your partner is the paler yellow marker labelled P."
        ),
        LegendItem(
            symbol: "circle", tint: .secondary,
            title: "L and R are the two opponents",
            detail: "Left and right as you look at the diagram. The answer names the one it is aimed at."
        ),
        LegendItem(
            symbol: "circle.fill", tint: Color(red: 0.85, green: 0.95, blue: 0.2),
            title: "The small ball is your contact point",
            detail: "It is where you are hitting from, not where the ball is going. Its height is written under the diagram."
        ),
        LegendItem(
            symbol: "rectangle.split.3x1", tint: Color(red: 0.72, green: 0.31, blue: 0.22),
            title: "The red band is the kitchen",
            detail: "Seven feet either side of the net. You cannot volley in it, so who is standing at that line decides what is safe."
        ),
        LegendItem(
            symbol: "arrow.up.and.down", tint: .accentColor,
            title: "Ball height decides everything",
            detail: "Above net height is attackable, at or below it is not. It is the single most important line in the description."
        ),
        LegendItem(
            symbol: "figure.walk", tint: .accentColor,
            title: "Feet, not the score, pick the shot",
            detail: "Whoever has not reached the kitchen line is the target. The score is shown as context, not as a hint."
        ),
    ]
}
