import SwiftUI

/// The core loop: read the court, pick the shot, see the principle.
struct DrillSessionView: View {
    let phase: RallyPhase?
    let sessionLength: Int

    @EnvironmentObject private var subscriptions: SubscriptionService
    @EnvironmentObject private var progress: ProgressStore
    @EnvironmentObject private var limiter: PracticeLimiter
    @EnvironmentObject private var reviews: ReviewPromptTracker
    @Environment(\.dismiss) private var dismiss

    @State private var questions: [DrillQuestion] = []
    @State private var index = 0
    @State private var picked: Int?
    @State private var correctCount = 0
    @State private var showPaywall = false
    @State private var finished = false

    init(phase: RallyPhase? = nil, sessionLength: Int = 10) {
        self.phase = phase
        self.sessionLength = sessionLength
    }

    var body: some View {
        Group {
            if finished {
                summary
            } else if let question = questions[safe: index] {
                drill(question)
            } else {
                ProgressView().onAppear(perform: build)
            }
        }
        .navigationTitle(phase?.title ?? "Mixed rally")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .onAppear { if questions.isEmpty { build() } }
    }

    // MARK: - Drill

    private func drill(_ question: DrillQuestion) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header(question)

                CourtDiagramView(position: question.position)
                    .frame(maxHeight: 340)

                situationLine(question.position)

                Text(picked == nil ? "What's the shot?" : "")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(Array(question.options.enumerated()), id: \.element.id) { offset, shot in
                    optionButton(shot, offset: offset, question: question)
                }

                if picked != nil { answerCard(question) }
            }
            .padding()
        }
        .safeAreaInset(edge: .bottom) {
            if picked != nil {
                Button(index + 1 >= questions.count ? "Finish" : "Next ball") {
                    advance()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .padding()
                .background(.bar)
            }
        }
    }

    private func header(_ question: DrillQuestion) -> some View {
        HStack {
            Text("Ball \(index + 1) of \(questions.count)")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Spacer()
            if !subscriptions.isPro {
                Label("\(limiter.remaining(isPro: false)) left today", systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func situationLine(_ position: RallyPosition) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(position.phase.title).font(.subheadline.weight(.semibold))
            Text("\(position.ballHeight.label). You're \(position.yourZone.label.lowercased()). \(position.scoreLine).")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func optionButton(_ shot: Shot, offset: Int, question: DrillQuestion) -> some View {
        let isAnswer = offset == question.answerIndex
        let isPicked = picked == offset
        return Button {
            guard picked == nil else { return }
            select(offset, in: question)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(shot.type.label).font(.body.weight(.semibold))
                    Text("\(shot.type.blurb) · \(shot.target.label)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                if picked != nil {
                    Image(systemName: isAnswer ? "checkmark.circle.fill"
                                               : (isPicked ? "xmark.circle.fill" : "circle"))
                        .foregroundStyle(isAnswer ? .green : (isPicked ? .red : .secondary))
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background(isAnswer: isAnswer, isPicked: isPicked))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(picked != nil)
    }

    private func background(isAnswer: Bool, isPicked: Bool) -> Color {
        guard picked != nil else { return Color(.secondarySystemBackground) }
        if isAnswer { return Color.green.opacity(0.18) }
        if isPicked { return Color.red.opacity(0.15) }
        return Color(.secondarySystemBackground)
    }

    private func answerCard(_ question: DrillQuestion) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(question.verdict.principle, systemImage: "lightbulb.fill")
                .font(.subheadline.weight(.bold))
            Text(question.verdict.why)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Summary

    private var summary: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("\(correctCount) of \(questions.count)")
                .font(.system(size: 52, weight: .bold, design: .rounded))
            Text(summaryBlurb).font(.headline).multilineTextAlignment(.center)
            if let weakest = progress.weakestPhase {
                Text("Next up: \(weakest.title.lowercased()) is your weakest phase.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .padding()
    }

    private var summaryBlurb: String {
        let ratio = questions.isEmpty ? 0 : Double(correctCount) / Double(questions.count)
        switch ratio {
        case 0.9...: return "That's tournament-grade shot selection."
        case 0.7..<0.9: return "Solid. The misses are where the rating is."
        case 0.5..<0.7: return "Middle of the pack. Read their feet before you swing."
        default: return "This is the phase to live in for a week."
        }
    }

    // MARK: - Flow

    private func build() {
        let seed = UInt64(Date().timeIntervalSince1970)
        if let phase {
            questions = (0..<sessionLength).map {
                PositionGenerator.question(phase: phase, seed: seed &+ UInt64($0 &* 104_729))
            }
        } else {
            questions = PositionGenerator.session(count: sessionLength, seed: seed)
        }
    }

    private func select(_ offset: Int, in question: DrillQuestion) {
        guard limiter.canPractice(isPro: subscriptions.isPro) else {
            showPaywall = true
            return
        }
        picked = offset
        let wasCorrect = offset == question.answerIndex
        if wasCorrect { correctCount += 1 }
        progress.record(phase: question.position.phase, wasCorrect: wasCorrect)
        limiter.consume(isPro: subscriptions.isPro)
    }

    private func advance() {
        picked = nil
        if index + 1 >= questions.count {
            reviews.recordSessionFinished()
            finished = true
        } else if !limiter.canPractice(isPro: subscriptions.isPro) {
            showPaywall = true
            finished = true
        } else {
            index += 1
        }
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
