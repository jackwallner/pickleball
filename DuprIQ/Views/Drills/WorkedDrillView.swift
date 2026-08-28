import SwiftUI

/// The worked-calculation runner.
///
/// The difference from a quiz is what happens after the answer: a quiz shows a
/// paragraph, this shows numbered steps. That is deliberate. A candidate who
/// misses a derating problem almost never misses the arithmetic, they miss one
/// step, and a paragraph hides which one. Numbered steps let them find it.
struct WorkedDrillView: View {
    let drill: Drill
    let scenarios: [WorkedRead]

    @EnvironmentObject private var progress: ProgressStore

    @State private var index = 0
    @State private var selection: Int?
    @State private var score = 0
    @State private var finished = false
    @State private var confettiTrigger = 0
    @State private var answerRect: CGRect?

    var body: some View {
        if finished {
            DrillCompleteView(drill: drill, score: score, total: scenarios.count)
        } else {
            drillBody
        }
    }

    private var scenario: WorkedRead { scenarios[index] }
    private var answered: Bool { selection != nil }

    /// Seeded by the scenario id so the correct answer is not always in the
    /// authored slot, and stays put across a re-render.
    private var shuffled: (labels: [String], answerIndex: Int) {
        ChoiceShuffle.shuffledChoices(
            labels: scenario.choices,
            answerIndex: scenario.answerIndex,
            seed: scenario.id
        )
    }

    private var drillBody: some View {
        VStack(spacing: 16) {
            // Completed, not current: the bar counts an item once it has been
            // graded, so the final answer fills it instead of leaving the run
            // permanently one short of done.
            ProgressView(value: Double(index + (answered ? 1 : 0)), total: Double(max(scenarios.count, 1)))
                .tint(Theme.court)
                .animation(.easeOut(duration: 0.3), value: answered)
            VStack(spacing: 16) {
                CenteringScrollView {
                    VStack(spacing: 18) {
                        Text(scenario.situation)
                            .font(Theme.display(21))
                            .foregroundStyle(Theme.ink)
                            .multilineTextAlignment(.center)
                        CourtDiagramView(position: scenario.position)
                            .frame(maxWidth: 320)
                            .frame(height: 300)
                            .padding(.horizontal, 4)
                        ChoiceList(
                            labels: shuffled.labels,
                            selection: selection,
                            answerIndex: shuffled.answerIndex
                        ) { pick in
                            select(pick)
                        }
                        if answered {
                            if let missNote { MissNoteView(note: missNote) }
                            WorkedStepsView(steps: scenario.steps, principle: scenario.principle)
                            ReportIssueButton(context: reportContext)
                        }
                    }
                    .padding(.horizontal, 4)
                }
                footer
            }
            .id(index)
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
        }
        .padding()
        .frame(maxWidth: Theme.readableContentWidth)
        .frame(maxWidth: .infinity)
        .background(Theme.background)
        .navigationTitle(drill.title)
        .navigationBarTitleDisplayMode(.inline)
        .drillStage(answerRect: $answerRect)
        .overlay {
            ConfettiBurst(
                trigger: confettiTrigger,
                origin: .init(x: 0.5, y: 0.35),
                sourceRect: answerRect
            )
        }
    }

    /// The named mistake behind the pick, when this scenario knows one. Only
    /// generated scenarios carry them today; authored ones simply show nothing.
    private var missNote: String? {
        guard let pick = selection, pick != shuffled.answerIndex,
              shuffled.labels.indices.contains(pick)
        else { return nil }
        return scenario.mistakes[shuffled.labels[pick]]?.summary
    }

    private var reportContext: ContentReport.Context {
        ContentReport.Context(
            itemID: scenario.id,
            prompt: scenario.situation,
            principle: scenario.principle,
            correctAnswer: shuffled.labels[shuffled.answerIndex],
            selectedAnswer: selection.flatMap { shuffled.labels.indices.contains($0) ? shuffled.labels[$0] : nil }
        )
    }

    private var footer: some View {
        Button {
            advance()
        } label: {
            Text(index == scenarios.count - 1 ? "Finish" : "Next").primaryCTA()
        }
        .disabled(!answered)
        .opacity(answered ? 1 : 0.4)
    }

    private func select(_ pick: Int) {
        guard selection == nil else { return }
        withAnimation(.easeOut(duration: 0.25)) { selection = pick }
        let correct = pick == shuffled.answerIndex
        if correct {
            score += 1
            confettiTrigger += 1
        }
        progress.recordItem(id: scenario.id, correct: correct)
        PracticeRecordStore.shared.record(itemID: scenario.id, roomID: roomID, correct: correct)
        if correct {
            Haptics.correctAnswer()
            SoundPlayer.play(.success)
        } else {
            Haptics.wrongAnswer()
            SoundPlayer.play(.miss)
        }
    }

    private func advance() {
        if index == scenarios.count - 1 {
            finished = true
        } else {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                index += 1
                selection = nil
            }
        }
    }

    /// The room a worked example belongs to, so its result lands in the same
    /// stats bucket as the generated practice for the same skill.
    private var roomID: String { DrillLibrary.roomID(forDrillID: drill.id) }
}
