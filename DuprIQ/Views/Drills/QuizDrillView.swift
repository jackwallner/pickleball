import SwiftUI

struct QuizDrillView: View {
    let drill: Drill
    let questions: [QuizQuestion]

    @EnvironmentObject private var progress: ProgressStore

    @State private var index = 0
    @State private var selection: Int?
    @State private var score = 0
    @State private var finished = false
    @State private var confettiTrigger = 0
    /// The correct answer row, so the burst launches from what was right.
    @State private var answerRect: CGRect?

    var body: some View {
        if finished {
            DrillCompleteView(drill: drill, score: score, total: questions.count)
        } else {
            drillBody
        }
    }

    private var question: QuizQuestion { questions[index] }
    private var answered: Bool { selection != nil }

    /// Deterministic per-question shuffle so the correct answer isn't always
    /// in the authored slot; stable across re-render since it's seeded by id.
    private var shuffled: (labels: [String], answerIndex: Int) {
        ChoiceShuffle.shuffledChoices(labels: question.choices, answerIndex: question.answerIndex, seed: question.id)
    }

    private var drillBody: some View {
        VStack(spacing: 16) {
            // Completed, not current. See WorkedDrillView for the same rule.
            ProgressView(value: Double(index + (answered ? 1 : 0)), total: Double(max(questions.count, 1)))
                .tint(Theme.court)
                .animation(.easeOut(duration: 0.3), value: answered)
            VStack(spacing: 16) {
                QuestionPager(
                    prompt: question.prompt,
                    givens: question.givens,
                    explanation: question.explanation,
                    principle: question.principle,
                    reportContext: answered ? reportContext : nil,
                    answered: answered
                ) {
                    ChoiceList(labels: shuffled.labels, selection: selection, answerIndex: shuffled.answerIndex) { pick in
                        select(pick)
                    }
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
        .tabBarClearance()
        .drillStage(answerRect: $answerRect)
        .overlay {
            ConfettiBurst(
                trigger: confettiTrigger,
                origin: .init(x: 0.5, y: 0.35),
                sourceRect: answerRect
            )
        }
        .navigationTitle(drill.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var footer: some View {
        Group {
            if answered {
                Button {
                    advance()
                } label: {
                    Text(index + 1 < questions.count ? "Next Question" : "Finish").primaryCTA()
                }
            } else {
                Text("Question \(index + 1) of \(questions.count)")
                    .font(.caption)
                    .foregroundStyle(Theme.inkTertiary)
                    .frame(height: 54)
            }
        }
    }

    private var reportContext: ContentReport.Context {
        ContentReport.Context(
            itemID: question.id,
            prompt: question.prompt,
            principle: question.principle,
            correctAnswer: shuffled.labels[shuffled.answerIndex],
            selectedAnswer: selection.flatMap { shuffled.labels.indices.contains($0) ? shuffled.labels[$0] : nil }
        )
    }

    private func select(_ choiceIndex: Int) {
        guard !answered else { return }
        selection = choiceIndex
        let correct = choiceIndex == shuffled.answerIndex
        progress.recordItem(id: question.id, correct: correct)
        PracticeRecordStore.shared.record(itemID: question.id, courtID: DrillLibrary.courtID(forDrillID: drill.id), correct: correct)
        if correct {
            score += 1
            confettiTrigger += 1
            Haptics.correctAnswer()
            SoundPlayer.play(.success)
        } else {
            Haptics.wrongAnswer()
            SoundPlayer.play(.miss)
        }
    }

    private func advance() {
        if index + 1 < questions.count {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                selection = nil
                index += 1
            }
        } else {
            withAnimation(.easeInOut(duration: 0.3)) { finished = true }
        }
    }
}
