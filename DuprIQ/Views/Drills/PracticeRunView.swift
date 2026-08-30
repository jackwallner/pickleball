import SwiftUI

/// What a run is and when it ends.
enum PracticeMode: Equatable {
    /// Generated questions for one skill, forever, until the player stops.
    case endless(RallyPhase)
    /// Mixed generated questions against a countdown.
    case timed
    /// A fixed list of items the scheduler says are due.
    case review

    var isGenerated: Bool { self != .review }
}

/// The runner behind Endless Practice, the Timed Challenge, and Fix My
/// Mistakes. All three are the same beat as Quick Session (pick, grade
/// immediately, the answer holds, explicit Next); what differs is only where
/// the questions come from and what ends the run.
///
/// `QuickSessionView` is deliberately left alone rather than generalised into
/// this: it is the shipped first-run flow and its snapshot/transition
/// behaviour is tuned. This shares the same components, not the same file.
struct PracticeRunView: View {
    let mode: PracticeMode

    @EnvironmentObject private var progress: ProgressStore
    @EnvironmentObject private var subscriptions: SubscriptionService
    @StateObject private var records = PracticeRecordStore.shared

    /// Snapshotted, never re-derived from the parent mid-run. Grading
    /// publishes store changes that re-render whoever pushed us, and a
    /// re-derived list would swap a different question under the live index.
    @State private var items: [QuickItem]
    @State private var index = 0
    @State private var score = 0
    /// Questions actually answered. An endless or timed run is scored out of
    /// this, not out of `index` (which lags by one until the player advances)
    /// and not out of `items.count` (which is just however much has been
    /// generated so far).
    @State private var attempted = 0
    @State private var finished = false
    @State private var selection: Int?

    @State private var secondsRemaining = Self.challengeSeconds
    @State private var confettiTrigger = 0
    @State private var confettiParticleCount = 30
    @State private var flashOpacity: Double = 0
    @State private var answerRect: CGRect?
    @State private var streak = 0

    @Environment(\.dismiss) private var dismiss

    static let challengeSeconds = 90
    /// How many generated questions to mint at a time. Dealing is rejection
    /// sampling, so a batch costs real work; topping up near the end of the
    /// current one keeps that off the tap that advances the question.
    private static let batchSize = 8
    private static let topUpThreshold = 3

    init(mode: PracticeMode, items: [QuickItem] = []) {
        self.mode = mode
        switch mode {
        case .endless(let skill):
            _items = State(initialValue: EndlessPractice.items(for: skill, count: Self.batchSize))
        case .timed:
            _items = State(initialValue: EndlessPractice.mixedItems(count: Self.batchSize))
        case .review:
            _items = State(initialValue: items)
        }
    }

    var body: some View {
        if items.isEmpty {
            // Only review can legitimately arrive empty (a stale queue, a
            // filtered-out locked item, a deep link that outlived its items).
            // Sending it to the completion screen faked a finished session.
            SessionEmptyView(
                title: mode == .review ? "Nothing due right now" : "Nothing to practise yet",
                message: mode == .review
                    ? "You have no mistakes waiting. Answer a few questions and anything you miss will show up here."
                    : "This run could not build any questions. Try again in a moment."
            )
        } else if finished {
            DrillCompleteView(drill: completedDrill, score: score, total: gradedTotal)
        } else {
            runBody
        }
    }

    private var item: QuickItem { items[min(index, items.count - 1)] }
    private var answered: Bool { selection != nil }
    /// Endless and timed runs are scored out of what was actually attempted,
    /// not out of a deck size that does not exist.
    private var gradedTotal: Int { mode == .review ? items.count : attempted }

    private var completedDrill: Drill {
        switch mode {
        case .endless(let skill): return EndlessPractice.drill(for: skill)
        case .timed: return EndlessPractice.challengeDrill
        case .review: return SessionBuilder.reviewDrill
        }
    }

    private var title: String {
        switch mode {
        case .endless(let skill): return skill.title
        case .timed: return "Timed Challenge"
        case .review: return "Fix My Mistakes"
        }
    }

    // MARK: - Body

    private var runBody: some View {
        VStack(spacing: 16) {
            statusBar
            VStack(spacing: 12) {
                QuestionPager(
                    prompt: item.prompt,
                    givens: item.givens,
                    position: item.position,
                    targetOpponent: item.targetOpponent,
                    // The generated items in a timed run and in Fix My Mistakes
                    // are the same balls the main loop plays, so they get the
                    // same first-person court. Leaving these out was an
                    // oversight of the pivot, not a decision: `QuickSessionView`
                    // passed them and this runner did not, so the two
                    // Pro-locked modes were quietly still serving the overhead
                    // diagram and a list of sentences the pivot replaced.
                    // Authored items carry no shots and correctly fall through
                    // to chips and a choice list.
                    shots: item.shots,
                    answerIndex: item.answerIndex,
                    selection: selection,
                    onPickShot: { grade($0) },
                    explanation: item.explanation,
                    steps: item.steps,
                    principle: item.principle,
                    missNote: missNote,
                    reportContext: answered ? reportContext : nil,
                    answered: answered,
                    eyebrow: item.sourceLabel.uppercased()
                ) {
                    ChoiceList(labels: item.choices, selection: selection, answerIndex: item.answerIndex) { pick in
                        grade(pick)
                    }
                }
                footer
            }
            .id(item.id)
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
        }
        .padding()
        .frame(maxWidth: Theme.readableContentWidth)
        .frame(maxWidth: .infinity)
        .background(Theme.background)
        .tabBarClearance()
        .drillStage(answerRect: $answerRect)
        .overlay { Theme.rightGreen.opacity(flashOpacity).allowsHitTesting(false).ignoresSafeArea() }
        .overlay {
            ConfettiBurst(
                trigger: confettiTrigger,
                origin: .init(x: 0.5, y: 0.35),
                particleCount: confettiParticleCount,
                sourceRect: answerRect
            )
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // An endless run has no natural end, so it must always offer one.
            if mode != .timed {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(mode == .review ? "Close" : "Finish") { finish() }
                        .foregroundStyle(Theme.court)
                }
            }
        }
        .task { await runClock() }
    }

    @ViewBuilder
    private var statusBar: some View {
        switch mode {
        case .timed:
            HStack(spacing: 10) {
                Image(systemName: "timer")
                    .foregroundStyle(secondsRemaining <= 10 ? Theme.ball : Theme.inkSecondary)
                Text("\(secondsRemaining)s")
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(secondsRemaining <= 10 ? Theme.ball : Theme.ink)
                Spacer()
                Text("\(score) correct")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.court)
                    .monospacedDigit()
            }
            .padding(.horizontal, 4)
        case .review:
            // Completed, not current. See WorkedDrillView for the same rule.
            ProgressView(value: Double(index + (answered ? 1 : 0)), total: Double(max(items.count, 1)))
                .tint(Theme.court)
                .animation(.easeOut(duration: 0.3), value: answered)
        case .endless:
            HStack {
                Text("\(score) of \(attempted) correct")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.inkSecondary)
                    .monospacedDigit()
                Spacer()
                if streak >= 3 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                        Text("\(streak)")
                            .monospacedDigit()
                    }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.ball)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private var footer: some View {
        Group {
            if answered {
                Button {
                    advance()
                } label: {
                    Text(isLastItem ? "Finish" : "Next").primaryCTA()
                }
            } else {
                Text(counterText)
                    .font(.caption)
                    .foregroundStyle(Theme.inkTertiary)
                    .frame(height: 54)
            }
        }
    }

    private var isLastItem: Bool {
        mode == .review && index + 1 >= items.count
    }

    private var counterText: String {
        mode == .review ? "\(index + 1) of \(items.count)" : "Question \(index + 1)"
    }

    // MARK: - Clock

    private func runClock() async {
        guard mode == .timed else { return }
        while secondsRemaining > 0 && !finished {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled else { return }
            secondsRemaining -= 1
        }
        guard !finished else { return }
        Haptics.impact(.rigid)
        finish()
    }

    // MARK: - Grading

    private func grade(_ pick: Int) {
        guard selection == nil else { return }
        selection = pick
        attempted += 1
        let correct = pick == item.answerIndex
        records.record(itemID: item.id, courtID: item.courtID, correct: correct, isReviewable: item.isReviewable)
        // See QuickSessionView: a generated question is a one-off, its mistake
        // is not, so the PATTERN is what gets banked and worked back off.
        if correct {
            for pattern in Set(item.mistakes.values) {
                records.resolveMistake(pattern.id)
            }
        } else if let pattern = item.mistake(forChoiceAt: pick) {
            records.recordMistake(pattern)
        }
        // Generated ids are unique per question, so feeding them to the
        // seen/missed sets would grow those sets forever and teach the daily
        // mix nothing. Authored items still feed it.
        if !mode.isGenerated {
            progress.recordItem(id: item.id, correct: correct)
        }
        if correct {
            score += 1
            streak += 1
            landCorrect()
        } else {
            streak = 0
            Haptics.wrongAnswer()
            SoundPlayer.play(.miss)
        }
    }

    private var missNote: String? {
        guard let pick = selection, pick != item.answerIndex else { return nil }
        return item.mistake(forChoiceAt: pick)?.summary
    }

    private var reportContext: ContentReport.Context {
        ContentReport.Context(
            itemID: item.id,
            prompt: item.prompt,
            principle: item.principle,
            correctAnswer: item.choices[item.answerIndex],
            selectedAnswer: selection.flatMap { item.choices.indices.contains($0) ? item.choices[$0] : nil }
        )
    }

    private func landCorrect() {
        confettiParticleCount = particleCount(forStreak: streak)
        confettiTrigger += 1
        Haptics.correctAnswer()
        SoundPlayer.play(.success)
        guard ConfettiBurst.celebrationsEnabled else { return }
        flashOpacity = 0.14
        withAnimation(.easeOut(duration: 0.5)) { flashOpacity = 0 }
    }

    private func particleCount(forStreak streak: Int) -> Int {
        switch streak {
        case 10...: return 90
        case 5..<10: return 60
        case 3..<5: return 44
        default: return 28
        }
    }

    private func advance() {
        if isLastItem {
            finish()
            return
        }
        topUpIfNeeded()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            selection = nil
            index += 1
        }
    }

    /// Keeps a generated run supplied without ever letting the index run past
    /// the end of the array.
    private func topUpIfNeeded() {
        guard mode.isGenerated, items.count - index <= Self.topUpThreshold else { return }
        switch mode {
        case .endless(let skill):
            items += EndlessPractice.items(for: skill, count: Self.batchSize)
        case .timed:
            items += EndlessPractice.mixedItems(count: Self.batchSize)
        case .review:
            break
        }
    }

    private func finish() {
        if mode == .timed {
            records.recordChallengeScore(score)
        }
        // A run the player quit before answering anything is not an
        // achievement; sending it to the completion screen would fake one.
        guard attempted > 0 || mode == .review else {
            dismiss()
            return
        }
        withAnimation(.easeInOut(duration: 0.3)) { finished = true }
    }
}
