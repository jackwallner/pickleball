import SwiftUI

/// How to read the court you are standing on, shown once on first launch and
/// available forever from the lobby and from Settings.
///
/// The product's whole task is reading a live situation. A player who has not
/// been told which body is theirs, where the kitchen is, or that the ball's
/// height against the net tape is the thing deciding the answer, is guessing at
/// question one and will read the app as a quiz rather than as coaching.
///
/// This page used to teach a plan-view diagram and a caption that spelled the
/// ball height out in words. Both are gone: the height is now something you
/// look at, so the primer's job changed from "here is a legend" to "here is
/// what to look at, and in what order".
struct CourtPrimerView: View {
    static let seenKey = "onboarding.hasSeenCourtPrimer"

    let isFirstRun: Bool

    @AppStorage(CourtPrimerView.seenKey) private var hasSeenPrimer = false
    @Environment(\.dismiss) private var dismiss

    init(isFirstRun: Bool = false) {
        self.isFirstRun = isFirstRun
    }

    /// A fixed, legal example position so the legend points at something real:
    /// one opponent up at the line, one still short, and a ball sitting up.
    private static let example = RallyPosition(
        id: "primer", phase: .thirdShot,
        you: CourtPoint(x: 6.5, y: 3.5),
        partner: CourtPoint(x: 14, y: 4),
        opponentLeft: CourtPoint(x: 6, y: 29.6),
        opponentRight: CourtPoint(x: 14.5, y: 34.5),
        contact: CourtPoint(x: 7, y: 6.2),
        ballHeight: .aboveNet,
        yourScore: 4, theirScore: 6, isServingTeam: true
    )

    private static let exampleOptions: [Shot] = [
        Shot(.drop, .crossCourtKitchen),
        Shot(.drive, .atFeet),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Every ball is a rally position, seen from where you are standing.")
                        .font(.headline)
                        .foregroundStyle(Theme.ink)

                    CourtPOVView(
                        position: Self.example,
                        options: Self.exampleOptions,
                        aimPoints: ShotAiming.aimPoints(
                            for: Self.exampleOptions, in: Self.example
                        ),
                        phase: .deciding,
                        onPick: nil,
                        chrome: .embedded
                    )
                    // `.embedded`, and not the default. The drill chrome
                    // reserves a HUD band and a verdict band it will never be
                    // given here, which inside a 300 point box is most of the
                    // box: the camera was fitting the whole court into a strip
                    // about eighty points tall.
                    .frame(height: 360)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .accessibilityHidden(true)

                    ForEach(Self.legend, id: \.title) { item in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: item.symbol)
                                .font(.body)
                                .foregroundStyle(item.tint)
                                .frame(width: 24)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Theme.ink)
                                Text(item.detail)
                                    .font(.footnote)
                                    .foregroundStyle(Theme.inkSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }

                    Text("""
                    Four shots are offered, drawn where they would land. One of \
                    them is the answer the coaching system gives, and after you \
                    pick, the app names the principle behind it. Shot selection \
                    is coached opinion, so the principle is the thing to argue \
                    with.
                    """)
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .padding()
                .frame(maxWidth: Theme.readableContentWidth)
                .frame(maxWidth: .infinity)
            }
            .background(Theme.background)
            .scrollIndicators(.visible)
            .accessibilityHint("Scroll for the full court reading guide")
            .safeAreaInset(edge: .bottom) {
                Button(isFirstRun ? "Start playing" : "Got it") {
                    hasSeenPrimer = true
                    dismiss()
                }
                .primaryCTA(color: Theme.court)
                .padding(.horizontal)
                .padding(.bottom, 8)
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
            symbol: "arrow.up.and.down", tint: Theme.opticInk,
            title: "Read the ball against the net tape",
            detail: "The one fact that decides most answers. A ball above the white tape can be attacked; one at or below it cannot, whatever else is true. The line dropping from the ball to the paint is there so you can judge its height, not its distance."
        ),
        LegendItem(
            symbol: "circle.dashed", tint: Theme.court,
            title: "Read their feet, not their bodies",
            detail: "Each player stands in a lit ring. Whoever has not reached the kitchen line is the target, and how far apart the two of them are standing decides whether the seam beats either body."
        ),
        LegendItem(
            symbol: "person.2.fill", tint: Theme.inkSecondary,
            title: "L and R are the two opponents",
            detail: "They are dressed identically on purpose: telling them apart is the read, not a colour code. Your own back is in the near field, and P is your partner."
        ),
        LegendItem(
            symbol: "rectangle.split.3x1", tint: Theme.kitchen,
            title: "The clay band is the kitchen",
            detail: "Seven feet either side of the net. Nobody can volley in it, so who is standing at that line decides what is safe to hit."
        ),
        LegendItem(
            symbol: "scope", tint: Theme.opticInk,
            title: "You answer by aiming",
            detail: "The four rings are the four places you could put this ball. The caption on each says the shape of the shot; where the ring sits is the target."
        ),
        LegendItem(
            symbol: "timer", tint: Theme.kitchen,
            title: "There is a clock",
            detail: "A ball you did not decide about is a ball you did not hit, so the clock counts as a miss. Change it, or turn it off, in Settings."
        ),
    ]
}
