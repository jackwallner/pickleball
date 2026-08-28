import SwiftUI

private enum QuickSessionPurpose {
    case quickSession(isDaily: Bool)
    case dailyDrill(DailyDrillChallenge)
    case matchWarmUp

    var drill: Drill {
        switch self {
        case .quickSession: return SessionBuilder.sessionDrill
        case .dailyDrill: return DailyDrillContent.drill
        case .matchWarmUp: return SessionBuilder.matchWarmUpDrill
        }
    }

    var navigationTitle: String { drill.title }
}

/// The Get Started session: a short, UNIFORM run of single-select choice
/// items pulled from across the rooms. Every item follows the same beat -
/// pick, grade immediately, the correct answer highlights and HOLDS, then an
/// explicit Next - so there's no interstitial or mixed grading path to fight
/// the transition. (The old MixedSessionView packed flip-flashcards, quiz,
/// and hand-match into one screen with a per-switch interstitial; that mix
/// of grading paths is what made it look like it skipped the right answer.)
struct QuickSessionView: View {
    /// Snapshotted at first construction, never re-read from the parent.
    /// `SessionBuilder.quickSession` shuffles and re-tiers on every call, and
    /// grading publishes `ProgressStore.seenItems`, which re-renders whichever
    /// parent (Home, the tour) built us. Holding the list as a plain `let`
    /// meant that re-render swapped a DIFFERENT question under the live index
    /// mid-answer, which read as "it changed the answer on me".
    @State private var items: [QuickItem]
    /// Set when the session is presented with no navigation stack of its own to
    /// escape through (the onboarding tour's fullScreenCover). Without it the
    /// player's FIRST question flow has no exit but finishing it, which is a
    /// trap, and a bad one right after the money page.
    private let onClose: (() -> Void)?
    /// Home's daily session spends the day's Get Started; the onboarding tour's
    /// demo run does not, so a brand-new player still finds a fresh Get Started
    /// waiting the first time they reach Home.
    private let purpose: QuickSessionPurpose

    init(items: [QuickItem], isDaily: Bool = true, onClose: (() -> Void)? = nil) {
        _items = State(initialValue: items)
        purpose = .quickSession(isDaily: isDaily)
        self.onClose = onClose
    }

    init(dailyDrill challenge: DailyDrillChallenge, onClose: (() -> Void)? = nil) {
        _items = State(initialValue: challenge.items)
        purpose = .dailyDrill(challenge)
        self.onClose = onClose
    }

    init(matchWarmUp items: [QuickItem], onClose: (() -> Void)? = nil) {
        _items = State(initialValue: items)
        purpose = .matchWarmUp
        self.onClose = onClose
    }

    @EnvironmentObject private var progress: ProgressStore
    @StateObject private var minuteStore = DailyDrillStore.shared

    @State private var index = 0
    @State private var score = 0
    @State private var finished = false
    @State private var selection: Int?
    @State private var answers: [Bool] = []
    @State private var minuteResult: DailyDrillResult?

    @State private var confettiTrigger = 0
    @State private var confettiParticleCount = 30
    @State private var flashOpacity: Double = 0
    /// The correct answer row, published by `ChoiceList`. The celebration
    /// launches from there, not from the middle of the screen.
    @State private var answerRect: CGRect?

    @State private var streak = 0
    @State private var streakBannerText: String?
    @State private var streakBannerTrigger = 0

    private static let streakMilestones: Set<Int> = [3, 5, 10]

    var body: some View {
        if items.isEmpty {
            // An empty session is NOT a finished one. Routing it to the
            // completion screen congratulated people on a run of zero questions,
            // which is both a lie and a dead end.
            SessionEmptyView(
                title: "Nothing to practise here yet",
                message: "This session could not find any questions. Open a room and answer a few, then try again.",
                onDone: onClose
            )
        } else if finished {
            completion
        } else {
            drillBody
        }
    }

    @ViewBuilder
    private var completion: some View {
        if case .dailyDrill = purpose, let minuteResult {
            DailyDrillResultView(result: minuteResult, recordsCompletion: true, onDone: onClose)
        } else {
            DrillCompleteView(drill: purpose.drill, score: score, total: items.count, onDone: onClose)
        }
    }

    private var item: QuickItem { items[index] }
    private var answered: Bool { selection != nil }

    private var drillBody: some View {
        VStack(spacing: 16) {
            // Completed, not current. See WorkedDrillView for the same rule.
            ProgressView(value: Double(index + (answered ? 1 : 0)), total: Double(max(items.count, 1)))
                .tint(Theme.court)
                .animation(.easeOut(duration: 0.3), value: answered)
            VStack(spacing: 12) {
                QuestionPager(
                    prompt: item.prompt,
                    givens: item.givens,
                    position: item.position,
                    targetOpponent: item.targetOpponent,
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
        .overlay(alignment: .top) {
            if let streakBannerText {
                StreakBanner(text: streakBannerText)
                    .padding(.top, 6)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .navigationTitle(purpose.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let onClose {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { onClose() }
                        .foregroundStyle(Theme.inkSecondary)
                }
            }
        }
    }

    private var footer: some View {
        Group {
            if answered {
                Button {
                    advance()
                } label: {
                    Text(index + 1 < items.count ? "Next" : "Finish").primaryCTA()
                }
            } else {
                Text("\(index + 1) of \(items.count)")
                    .font(.caption)
                    .foregroundStyle(Theme.inkTertiary)
                    .frame(height: 54)
            }
        }
    }

    // MARK: - Grading

    private func grade(_ pick: Int) {
        guard selection == nil else { return }
        selection = pick
        let correct = pick == item.answerIndex
        answers.append(correct)
        if item.isReviewable {
            progress.recordItem(id: item.id, correct: correct)
        }
        // Also feeds the spaced-repetition queue and the accuracy stats. The
        // daily mix is where most answers happen, so leaving it out would mean
        // Fix My Mistakes had almost nothing to work with.
        PracticeRecordStore.shared.record(
            itemID: item.trackingID,
            roomID: item.roomID,
            correct: correct,
            isReviewable: item.isReviewable
        )
        recordMistakePattern(pick: pick, correct: correct)
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

    /// A generated question never comes back, but the ERROR does. A wrong pick
    /// on a distractor the generator can name banks that pattern for targeted
    /// practice; a right answer on a problem that set the same trap works it
    /// back off. That is what makes "your misses come back" true here without
    /// storing a dictionary of dead question ids.
    private func recordMistakePattern(pick: Int, correct: Bool) {
        if correct {
            for pattern in Set(item.mistakes.values) {
                PracticeRecordStore.shared.resolveMistake(pattern.id)
            }
        } else if let pattern = item.mistake(forChoiceAt: pick) {
            PracticeRecordStore.shared.recordMistake(pattern)
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

    /// The dopamine landing: confetti + haptic + sound every time, escalating
    /// with a full-screen glow flash and a stronger haptic + banner at streak
    /// milestones. A miss keeps the existing gentle feedback in `grade`.
    private func landCorrect() {
        confettiParticleCount = particleCount(forStreak: streak)
        confettiTrigger += 1
        Haptics.correctAnswer()
        SoundPlayer.play(.success)

        guard ConfettiBurst.celebrationsEnabled else { return }
        flashOpacity = 0.14
        withAnimation(.easeOut(duration: 0.5)) { flashOpacity = 0 }

        guard Self.streakMilestones.contains(streak) else { return }
        Haptics.impact(.rigid, intensity: 1.0)
        announceStreak(streak)
    }

    private func particleCount(forStreak streak: Int) -> Int {
        switch streak {
        case 10...: return 90
        case 5..<10: return 60
        case 3..<5: return 44
        default: return 28
        }
    }

    private func announceStreak(_ streak: Int) {
        streakBannerTrigger += 1
        let trigger = streakBannerTrigger
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            streakBannerText = "\(streak) in a row!"
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            guard trigger == streakBannerTrigger else { return }
            withAnimation(.easeOut(duration: 0.3)) { streakBannerText = nil }
        }
    }

    private func finishSession() {
        switch purpose {
        case .quickSession(let isDaily):
            if isDaily { progress.markQuickSessionCompleted() }
        case .dailyDrill(let challenge):
            minuteResult = minuteStore.record(challenge: challenge, answers: answers)
        case .matchWarmUp:
            break
        }
        withAnimation(.easeInOut(duration: 0.3)) { finished = true }
    }

    private func advance() {
        if index + 1 < items.count {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                selection = nil
                index += 1
            }
        } else {
            finishSession()
        }
    }
}

/// Brief celebratory pill for a consecutive-correct milestone (3/5/10 in a row).
private struct StreakBanner: View {
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "flame.fill")
            Text(text)
                .font(.subheadline.weight(.heavy))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(Theme.ball, in: Capsule())
        .shadow(color: Theme.ball.opacity(0.4), radius: 10, y: 4)
    }
}
