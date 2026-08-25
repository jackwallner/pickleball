import SwiftUI

struct ProgressDashboardView: View {
    @EnvironmentObject private var progress: ProgressStore
    @EnvironmentObject private var subscriptions: SubscriptionService

    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            List {
                overallSection
                byPhaseSection
                historySection
                missedSection
            }
            .navigationTitle("Progress")
            .listSectionSpacing(.compact)
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 88)
            }
            .sheet(isPresented: $showPaywall) { PaywallView() }
        }
    }

    // MARK: - Sections

    private var overallSection: some View {
        Section("Overall") {
            LabeledContent("Day streak", value: "\(progress.streak)")
            LabeledContent("Balls answered", value: "\(progress.totalAnswered)")
            LabeledContent("Sessions", value: "\(progress.sessions.count)")
        }
    }

    private var byPhaseSection: some View {
        Section {
            ForEach(RallyPhase.allCases) { phase in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(phase.title)
                        Text("\(progress.attemptCount(for: phase)) balls")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    PhaseSignalBadge(signal: progress.signal(for: phase))
                }
            }
        } header: {
            Text("By phase")
        } footer: {
            Text("A phase shows a percentage once you've answered \(ProgressThreshold.sampleForAccuracy) balls in it. Before that it counts up, because one ball is not a measurement.")
        }
    }

    /// Session history and missed principles are the real Pro line.
    ///
    /// Phase accuracy stays free: it is on the lobby, it is what makes the free
    /// tier worth opening, and selling it back as a Pro feature while showing
    /// it to everyone was a claim the app could not keep.
    @ViewBuilder
    private var historySection: some View {
        Section {
            if subscriptions.isPro {
                if progress.recentSessions.isEmpty {
                    Text("No sessions yet. Finish a rally and it lands here.")
                        .font(.footnote).foregroundStyle(.secondary)
                } else {
                    ForEach(progress.recentSessions.prefix(15)) { session in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(session.title)
                                Text(session.date.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(session.correct)/\(session.answered)")
                                .font(.subheadline.monospacedDigit().weight(.semibold))
                                .foregroundStyle(PhaseSignalBadge.color(for: session.accuracy))
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            } else {
                lockedRow(
                    title: "Session history",
                    detail: "Every session you finish, with its date and score, kept for the last \(ProgressStore.maxSessions)."
                )
            }
        } header: {
            Text("Recent sessions")
        }
    }

    @ViewBuilder
    private var missedSection: some View {
        Section {
            if subscriptions.isPro {
                if progress.topMissedPrinciples.isEmpty {
                    Text("Nothing yet. Missed answers are grouped by the principle behind them.")
                        .font(.footnote).foregroundStyle(.secondary)
                } else {
                    ForEach(progress.topMissedPrinciples.prefix(8)) { miss in
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(miss.principle)
                                    .font(.subheadline.weight(.medium))
                                Text(miss.phaseTitle)
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(miss.count)x")
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            } else {
                lockedRow(
                    title: "Missed principles",
                    detail: "The coaching rules you keep getting wrong, ranked. This is the practice plan, not the percentage."
                )
            }
        } header: {
            Text("What to drill next")
        } footer: {
            if !subscriptions.isPro {
                Text("Accuracy by phase is free and always will be. Pro adds the history behind it.")
            }
        }
    }

    private func lockedRow(title: String, detail: String) -> some View {
        Button {
            showPaywall = true
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "lock.fill")
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                    Text("In DUPR IQ Pro")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("locked-\(title.lowercased().replacingOccurrences(of: " ", with: "-"))")
    }
}
