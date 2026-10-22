import SwiftUI

/// How you play, measured: mastery per principle, the traps that keep costing
/// points, and your recent runs. Opened from the court, never instead of it.
///
/// Mastery is free. Pro adds the ranked traps and the run history, which is
/// the line the paywall, the site and the store description all draw.
struct YourGameView: View {
    @EnvironmentObject private var mastery: MasteryStore
    @EnvironmentObject private var subscriptions: SubscriptionService
    @EnvironmentObject private var limiter: PracticeLimiter
    @Environment(\.dismiss) private var dismiss

    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    stats
                    principles
                    traps
                    runs
                }
                .padding(20)
                .frame(maxWidth: Theme.readableContentWidth)
                .frame(maxWidth: .infinity)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Your game")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("your-game-done")
                }
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                    .accessibilityIdentifier("open-settings")
                }
            }
            .sheet(isPresented: $showPaywall) { PaywallView(source: "your-game").pageSizedOnIPad() }
        }
        // Past XXXL the stat tiles truncate their labels to "day…".
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .preferredColorScheme(.dark)
    }

    // MARK: - Stats

    private var stats: some View {
        HStack(spacing: 12) {
            stat("\(mastery.streak)", label: "day streak")
            stat("\(mastery.totalAnswered)", label: "balls read")
            if subscriptions.isPro {
                stat("∞", label: "balls today")
            } else {
                stat("\(limiter.remaining(isPro: false))", label: "free today")
            }
        }
    }

    private func stat(_ value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(Theme.numeric(26, weight: .heavy))
                .foregroundStyle(Theme.ink)
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.inkSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    // MARK: - Principles

    private var principles: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Principles", detail: "Every answer is filed under one. Five balls before a number shows.")
            ForEach(Principle.measured) { principle in
                PrincipleRow(principle: principle, signal: mastery.signal(for: principle))
            }
        }
    }

    // MARK: - Pro

    private var traps: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("What's costing you points", detail: "The tempting wrong shots you take most. Focus points keep testing each one until you stop falling for it.")
            if !subscriptions.isPro {
                locked("See your traps ranked")
            } else if mastery.rankedMistakes.isEmpty {
                empty("No traps yet. Play a few runs.")
            } else {
                ForEach(mastery.rankedMistakes) { tally in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(tally.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.ink)
                            Text(tally.isOpen ? "Cost you \(tally.misses) \(tally.misses == 1 ? "point" : "points")" : "Fixed. You've stopped taking it.")
                                .font(.caption)
                                .foregroundStyle(tally.isOpen ? Theme.inkSecondary : Theme.rightGreen)
                        }
                        Spacer()
                        Text("\(tally.misses)")
                            .font(Theme.numeric(17, weight: .bold))
                            .foregroundStyle(tally.isOpen ? Theme.wrongRed : Theme.inkTertiary)
                    }
                    .padding(14)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private var runs: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Recent runs", detail: nil)
            if !subscriptions.isPro {
                locked("Keep every run you play")
            } else if mastery.rallies.isEmpty {
                empty("Finish a run and it shows up here.")
            } else {
                ForEach(mastery.rallies.prefix(20)) { run in
                    HStack {
                        Text(run.date, format: .dateTime.month(.abbreviated).day().hour().minute())
                            .font(.subheadline)
                            .foregroundStyle(Theme.inkSecondary)
                        Spacer()
                        Text("\(run.pointsWon) - \(run.pointsLost)")
                            .font(Theme.numeric(16, weight: .bold))
                            .foregroundStyle(Theme.ink)
                        Text("\(run.correct)/\(run.answered)")
                            .font(Theme.numeric(13))
                            .foregroundStyle(Theme.inkTertiary)
                            .frame(width: 52, alignment: .trailing)
                    }
                    .padding(.vertical, 6)
                    .accessibilityElement(children: .combine)
                    Divider().overlay(Theme.rule)
                }
            }
        }
    }

    // MARK: - Pieces

    private func sectionTitle(_ title: String, detail: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.ink)
                .accessibilityAddTraits(.isHeader)
            if let detail {
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func locked(_ title: String) -> some View {
        Button { showPaywall = true } label: {
            HStack {
                Image(systemName: "lock.fill")
                    .foregroundStyle(Theme.gold)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text(AppBrand.proName)
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(Theme.gold)
            }
            .padding(14)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(PressableCTAStyle())
        .accessibilityIdentifier("your-game-pro")
    }

    private func empty(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(Theme.inkTertiary)
    }
}

/// One principle and how reliably you pick its shot.
private struct PrincipleRow: View {
    let principle: Principle
    let signal: MasterySignal

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(principle.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text(readout)
                    .font(Theme.numeric(14, weight: .bold))
                    .foregroundStyle(readoutColor)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.rule)
                    Capsule()
                        .fill(barColor)
                        .frame(width: geo.size.width * fill)
                }
            }
            .frame(height: 6)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(principle.displayName), \(readout)")
    }

    private var fill: Double {
        switch signal {
        case .new: return 0
        case .building(let answered): return Double(answered) / Double(MasteryThreshold.sample) * 0.15
        case .measured(let value): return value
        }
    }

    private var readout: String {
        switch signal {
        case .new: return "New"
        case .building(let answered): return "\(answered) of \(MasteryThreshold.sample)"
        case .measured(let value): return "\(Int((value * 100).rounded()))%"
        }
    }

    private var readoutColor: Color {
        if case .measured = signal { return Theme.ink }
        return Theme.inkTertiary
    }

    private var barColor: Color {
        guard case .measured(let value) = signal else { return Theme.inkTertiary }
        switch value {
        case 0.8...: return Theme.rightGreen
        case 0.6..<0.8: return Theme.Surface.ball
        default: return Theme.wrongRed
        }
    }
}
