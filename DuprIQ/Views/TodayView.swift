import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var subscriptions: SubscriptionService
    @EnvironmentObject private var progress: ProgressStore
    @EnvironmentObject private var limiter: PracticeLimiter
    @EnvironmentObject private var reviews: ReviewPromptTracker

    @State private var path: [DrillRoute] = []
    @State private var showPaywall = false
    @State private var showEnjoymentGate = false
    @State private var showPrimer = false

    /// Where a lobby row goes. Routing through a value rather than a
    /// `NavigationLink` is what lets the free allowance be checked *before* a
    /// player has read a court they are not allowed to answer.
    struct DrillRoute: Hashable {
        let phase: RallyPhase?
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                practiceSection
                roomsSection
                helpSection
                if !subscriptions.isPro { upgradeSection }
            }
            .navigationTitle("DUPR IQ")
            .navigationDestination(for: DrillRoute.self) { route in
                DrillSessionView(phase: route.phase)
            }
            .contentMargins(.bottom, 60, for: .scrollContent)
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .sheet(isPresented: $showEnjoymentGate) { EnjoymentGateSheet() }
            .sheet(isPresented: $showPrimer) { CourtPrimerView() }
            .onAppear {
                if reviews.shouldShowEnjoymentGate { showEnjoymentGate = true }
            }
        }
    }

    // MARK: - Sections

    private var practiceSection: some View {
        Section {
            Button {
                start(phase: nil)
            } label: {
                row(
                    title: "Today's rally",
                    detail: "10 balls across every phase of the point",
                    systemImage: "figure.pickleball"
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("mixed-rally")

            if let recommendation = progress.recommendation {
                Button {
                    start(phase: recommendation.phase)
                } label: {
                    row(
                        // Before there is enough evidence, this is a suggestion,
                        // not a measurement. Calling an untouched phase someone's
                        // "weakest" is a claim the app has not earned.
                        title: recommendation.isMeasured
                            ? "Work your weakest phase"
                            : "Suggested next phase",
                        detail: recommendation.isMeasured
                            ? "\(recommendation.phase.title) is your lowest accuracy"
                            : "\(recommendation.phase.title), which you haven't drilled yet",
                        systemImage: recommendation.isMeasured ? "target" : "arrow.right.circle"
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("weakest-phase")
            }
        } header: {
            Text("Practice")
        } footer: {
            practiceFooter
        }
    }

    @ViewBuilder
    private var practiceFooter: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !subscriptions.isPro {
                Text("\(limiter.remaining(isPro: false)) of \(PracticeLimiter.freeDailyBalls) free balls left today.")
            }
            if progress.streak > 0 {
                Text("\(progress.streak) day streak. A day counts at \(ProgressThreshold.ballsForPracticeDay) balls.")
            } else if progress.totalAnswered > 0 {
                Text("\(progress.ballsToPracticeDay) more balls today and the streak starts.")
            }
        }
    }

    private var roomsSection: some View {
        Section("Rooms") {
            ForEach(RallyPhase.allCases) { phase in
                Button {
                    start(phase: phase)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(phase.title).foregroundStyle(.primary)
                            Text(phase.subtitle)
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        PhaseSignalBadge(signal: progress.signal(for: phase))
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("room-\(phase.rawValue)")
            }
        }
    }

    private var helpSection: some View {
        Section {
            Button {
                showPrimer = true
            } label: {
                row(
                    title: "How to read the court",
                    detail: "Markers, the kitchen, ball height, and what the answer is graded on",
                    systemImage: "questionmark.circle"
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("court-primer")
        }
    }

    private var upgradeSection: some View {
        Section {
            Button {
                showPaywall = true
            } label: {
                Label("Unlimited balls with Pro", systemImage: "infinity")
            }
            .accessibilityIdentifier("home-paywall")
        }
    }

    // MARK: - Pieces

    private func row(title: String, detail: String, systemImage: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(Color.accentColor)
                .frame(width: 22)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline).foregroundStyle(.primary)
                Text(detail).font(.footnote).foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    // MARK: - Flow

    /// The free cap is checked here, before the court is drawn. Discovering the
    /// paywall after reading a position and choosing a shot is a bait-and-switch
    /// even when the limit is documented.
    private func start(phase: RallyPhase?) {
        limiter.rollOverIfNeeded()
        guard limiter.canPractice(isPro: subscriptions.isPro) else {
            showPaywall = true
            return
        }
        path.append(DrillRoute(phase: phase))
    }
}

/// Renders what a phase's record actually supports: nothing, a sample count, or
/// a real percentage. A big red 0% after one ball is a lie the eye believes
/// before it reads the footnote explaining that it is not one.
struct PhaseSignalBadge: View {
    let signal: PhaseSignal

    var body: some View {
        switch signal {
        case .untried:
            Text("New")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityLabel("Not practised yet")
        case .building(let answered, let needed):
            Text("\(answered) of \(needed)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .accessibilityLabel("\(answered) of \(needed) balls toward an accuracy")
        case .measured(let accuracy):
            Text(accuracy.formatted(.percent.precision(.fractionLength(0))))
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .foregroundStyle(Self.color(for: accuracy))
                .accessibilityLabel("\(Int((accuracy * 100).rounded())) percent accurate")
        }
    }

    static func color(for accuracy: Double) -> Color {
        switch accuracy {
        case 0.8...: return .green
        case 0.6..<0.8: return .orange
        default: return .red
        }
    }
}
