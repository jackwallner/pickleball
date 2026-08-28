import SwiftUI

/// Picks which rally phase to drill. Small on purpose: the whole point of
/// Endless Practice is that it starts fast and never runs out, so this is one
/// tap between Home and the first court, not another lobby.
///
/// Every route here goes through `start(phase:)` rather than a
/// `NavigationLink`, because the free allowance has to be checked BEFORE a
/// court is drawn. Reading a position, choosing a shot and then meeting a
/// paywall is a bait-and-switch even when the limit is documented.
struct EndlessPickerView: View {
    @EnvironmentObject private var progress: ProgressStore
    @EnvironmentObject private var subscriptions: SubscriptionService
    @EnvironmentObject private var limiter: PracticeLimiter

    @State private var path: [DrillRoute] = []
    @State private var showPaywall = false

    /// Where a lobby row goes. Routing through a value rather than a
    /// `NavigationLink` is what lets the allowance be checked first.
    struct DrillRoute: Hashable {
        let phase: RallyPhase?
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 12) {
                    intro
                    mixedCard
                    ForEach(RallyPhase.allCases) { phase in
                        Button {
                            start(phase: phase)
                        } label: {
                            phaseCard(phase)
                        }
                        .buttonStyle(PressableCardStyle())
                        .accessibilityIdentifier("court-\(phase.rawValue)")
                    }
                    allowanceFooter
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
                .frame(maxWidth: Theme.readableContentWidth)
                .frame(maxWidth: .infinity)
            }
            .background(Theme.background)
            .navigationTitle("Endless Practice")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: DrillRoute.self) { route in
                DrillSessionView(phase: route.phase)
            }
            .sheet(isPresented: $showPaywall) { PaywallView(source: "dupriq_endless") }
        }
    }

    private var intro: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "infinity")
                .foregroundStyle(Theme.court)
            Text("Every position here is generated the moment you see it: new feet, new ball height, new score. You can practise as long as you like without seeing the same court twice.")
                .font(.subheadline)
                .foregroundStyle(Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.court.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.top, 12)
    }

    private var mixedCard: some View {
        Button {
            start(phase: nil)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "shuffle")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.ball)
                    .frame(width: 48, height: 48)
                    .background(Theme.ball.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Mixed rally")
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                    Text("Every phase, the way a real point arrives")
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSecondary)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.inkTertiary)
            }
            .padding(14)
            .themedCard()
            .contentShape(RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous))
        }
        .buttonStyle(PressableCardStyle())
        .accessibilityIdentifier("mixed-rally")
    }

    private func phaseCard(_ phase: RallyPhase) -> some View {
        HStack(spacing: 14) {
            Image(systemName: phase.icon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.court)
                .frame(width: 48, height: 48)
                .background(Theme.court.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(phase.title)
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                Text(phase.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSecondary)
            }
            Spacer(minLength: 4)
            PhaseSignalBadge(signal: progress.signal(for: phase))
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.inkTertiary)
        }
        .padding(14)
        .themedCard()
        .contentShape(RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous))
    }

    /// The allowance, stated before it runs out rather than at the moment it
    /// does. Only the generated loop is metered: the authored courts are finite
    /// and two of them are free forever, so counting them against a daily cap
    /// would quietly take back what the free tier promised.
    @ViewBuilder
    private var allowanceFooter: some View {
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
        .font(.caption)
        .foregroundStyle(Theme.inkTertiary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
        .padding(.top, 4)
    }

    /// The free cap is checked here, before the court is drawn.
    private func start(phase: RallyPhase?) {
        limiter.rollOverIfNeeded()
        guard limiter.canPractice(isPro: subscriptions.isPro) else {
            showPaywall = true
            return
        }
        path.append(DrillRoute(phase: phase))
    }
}
