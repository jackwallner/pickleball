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
    @State private var answeredCount = 0
    @State private var showPaywall = false
    @State private var showAbandonConfirmation = false
    @State private var finished = false
    /// True when the session ended because the free allowance ran out rather
    /// than because the player finished the balls they were promised.
    @State private var stoppedAtFreeLimit = false
    @State private var recordedSession = false

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
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    leave()
                } label: {
                    Label("Back", systemImage: "chevron.left")
                }
                .accessibilityIdentifier("nav-back")
            }
        }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        // Walking out mid-session used to throw the session away silently while
        // keeping the balls in the lifetime stats, so an abandoned session and
        // a finished one were indistinguishable afterwards.
        .confirmationDialog(
            "Leave this session?",
            isPresented: $showAbandonConfirmation,
            titleVisibility: .visible
        ) {
            Button("Leave, keep my \(answeredCount) balls", role: .destructive) {
                endSession(atFreeLimit: false)
                dismiss()
            }
            Button("Keep drilling", role: .cancel) { }
        } message: {
            Text("The balls you've already answered are recorded. The rest of this session is discarded.")
        }
        .onAppear { if questions.isEmpty { build() } }
    }

    // MARK: - Drill

    private func drill(_ question: DrillQuestion) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                header(question)

                CourtDiagramView(
                    position: question.position,
                    highlight: picked == nil ? nil : question.verdict.targetOpponent
                )
                .frame(maxHeight: picked == nil ? 300 : 240)

                situationLine(question.position)

                // The principle is the product, so it goes between the court and
                // the options the moment the ball is graded. Placement is what
                // makes it unmissable: scrolling to it instead pushed the court
                // off the top of the screen, which throws away the thing the
                // explanation is asking the player to look back at. The court
                // gives up a little height once there is a reason to read.
                if picked != nil {
                    answerCard(question)
                }

                Text(picked == nil ? "What's the shot?" : "The four you were offered")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(Array(question.options.enumerated()), id: \.element.id) { offset, shot in
                    optionButton(shot, offset: offset, question: question)
                }
            }
            .padding()
        }
        .safeAreaInset(edge: .bottom) {
            if picked != nil {
                Button(isLastBall ? "Finish" : "Next ball") {
                    advance()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .padding()
                .background(.bar)
                .accessibilityIdentifier("next-ball")
            }
        }
    }

    private var isLastBall: Bool { index + 1 >= questions.count }

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

    /// The decision inputs first, then the score. The score is context: the
    /// advisor does not branch on it, so presenting it alongside ball height
    /// would train players to look for a signal that is not there.
    private func situationLine(_ position: RallyPosition) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(position.phase.title).font(.subheadline.weight(.semibold))
            Text("\(position.ballHeight.label), hit \(position.contactSideLabel). You're \(position.yourZone.label.lowercased()).")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text("Context: \(position.scoreLine).")
                .font(.caption)
                .foregroundStyle(.tertiary)
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
                    // The whole phrase is the choice. Two rows both headed
                    // "Put it away" are one choice wearing two names.
                    Text(shot.label).font(.body.weight(.semibold))
                    Text(shot.type.blurb)
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
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background(isAnswer: isAnswer, isPicked: isPicked))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(picked != nil)
        .accessibilityIdentifier("shot-\(offset)")
        .accessibilityLabel(shot.label)
        // Green and a checkmark is not a result for someone who cannot see
        // either. The value carries the same information as the colour.
        .accessibilityValue(optionState(isAnswer: isAnswer, isPicked: isPicked))
    }

    private func optionState(isAnswer: Bool, isPicked: Bool) -> String {
        guard picked != nil else { return "" }
        switch (isAnswer, isPicked) {
        case (true, true): return "Correct. This was your answer."
        case (true, false): return "This was the correct answer."
        case (false, true): return "Incorrect. This was your answer."
        case (false, false): return "Not the answer, not selected."
        }
    }

    private func background(isAnswer: Bool, isPicked: Bool) -> Color {
        guard picked != nil else { return Color(.secondarySystemBackground) }
        if isAnswer { return Color.green.opacity(0.18) }
        if isPicked { return Color.red.opacity(0.15) }
        return Color(.secondarySystemBackground)
    }

    private func answerCard(_ question: DrillQuestion) -> some View {
        let wasCorrect = picked == question.answerIndex
        return VStack(alignment: .leading, spacing: 10) {
            Label(
                wasCorrect ? "Correct" : "Not this one",
                systemImage: wasCorrect ? "checkmark.circle.fill" : "xmark.circle.fill"
            )
            .font(.subheadline.weight(.bold))
            .foregroundStyle(wasCorrect ? Color.green : Color.red)

            Text(question.verdict.best.label)
                .font(.title3.weight(.semibold))

            if let target = question.verdict.targetOpponent {
                Label("Aimed at \(target.label), marked \(target.marker)", systemImage: "scope")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Divider()

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
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("answer-card")
    }

    // MARK: - Summary

    private var summary: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("\(correctCount) of \(max(answeredCount, 1))")
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .accessibilityLabel("\(correctCount) of \(max(answeredCount, 1)) correct")
            Text(summaryBlurb).font(.headline).multilineTextAlignment(.center)

            if stoppedAtFreeLimit {
                VStack(spacing: 8) {
                    Text("That's your \(PracticeLimiter.freeDailyBalls) free balls for today.")
                        .font(.subheadline.weight(.semibold))
                        .multilineTextAlignment(.center)
                    Text("The counter resets tomorrow. Pro removes it entirely.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("See Pro") { showPaywall = true }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("summary-paywall")
                }
                .padding(.top, 4)
            } else if let recommendation = progress.recommendation {
                Text(recommendation.isMeasured
                     ? "Next up: \(recommendation.phase.title.lowercased()) is your weakest phase."
                     : "Next up: try \(recommendation.phase.title.lowercased()), which you haven't drilled yet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("session-done")
        }
        .padding()
    }

    private var summaryBlurb: String {
        let denom = max(answeredCount, 1)
        let ratio = Double(correctCount) / Double(denom)
        switch ratio {
        case 0.9...: return "That's tournament-grade shot selection."
        case 0.7..<0.9: return "Solid. The misses are where the rating is."
        case 0.5..<0.7: return "Middle of the pack. Read their feet before you swing."
        default: return "This is the phase to live in for a week."
        }
    }

    // MARK: - Flow

    private func build() {
        let seed = drillSeed()
        // Never promise more balls than the free tier can actually grade. A
        // session that says "ball 4 of 10" and then stops at 4 is the paywall
        // arriving as a surprise.
        let allowance = limiter.remaining(isPro: subscriptions.isPro)
        let length = max(1, min(sessionLength, allowance))
        if let phase {
            questions = (0..<length).map {
                PositionGenerator.question(phase: phase, seed: seed &+ UInt64($0 &* 104_729))
            }
        } else {
            questions = PositionGenerator.session(count: length, seed: seed)
        }
    }

    private func drillSeed() -> UInt64 {
        #if DEBUG
        // A screenshot has to be the same court every run, or the App Store
        // asset is whatever the clock happened to say.
        if let fixed = DebugFixtures.requestedSeed { return fixed }
        #endif
        return UInt64(Date().timeIntervalSince1970)
    }

    private func select(_ offset: Int, in question: DrillQuestion) {
        // A session can straddle midnight. Roll over here, in an event handler
        // rather than a view body, so the cap the tap is graded against is
        // today's cap and not the one this screen was built with.
        limiter.rollOverIfNeeded()
        guard limiter.canPractice(isPro: subscriptions.isPro) else {
            endSession(atFreeLimit: true)
            return
        }
        picked = offset
        let wasCorrect = offset == question.answerIndex
        if wasCorrect { correctCount += 1 }
        answeredCount += 1
        progress.record(
            phase: question.position.phase,
            wasCorrect: wasCorrect,
            principle: question.verdict.principle
        )
        limiter.consume(isPro: subscriptions.isPro)
    }

    private func advance() {
        picked = nil
        limiter.rollOverIfNeeded()
        if isLastBall {
            endSession(atFreeLimit: !limiter.canPractice(isPro: subscriptions.isPro))
        } else if !limiter.canPractice(isPro: subscriptions.isPro) {
            endSession(atFreeLimit: true)
        } else {
            index += 1
        }
    }

    /// One place that closes a session, so the history, the review counter, and
    /// the free-limit state can never disagree about whether it happened.
    private func endSession(atFreeLimit: Bool) {
        stoppedAtFreeLimit = atFreeLimit
        if !recordedSession {
            recordedSession = true
            progress.recordSession(
                phase: phase, answered: answeredCount, correct: correctCount
            )
            if answeredCount > 0 { reviews.recordSessionFinished() }
        }
        finished = true
    }

    private func leave() {
        if answeredCount > 0 && !finished {
            showAbandonConfirmation = true
        } else {
            dismiss()
        }
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
