import SwiftUI

/// The core loop: you are on the court, the ball is coming, pick where it goes
/// before the clock runs out.
///
/// Three things about this screen are deliberate and were not true of the
/// version it replaces.
///
/// **The court never moves.** Grading used to shrink the diagram, insert an
/// explanation above the options and slide a bar in from the bottom, all on one
/// tap and none of it animated, which threw the option you had just tapped off
/// the screen. Here the court is a fixed, full-bleed layer and everything else
/// is an overlay on top of it. Nothing reflows, ever.
///
/// **A point is a rally, not a card.** Getting a decision right advances the
/// same point to your next shot; getting one wrong loses it. That is what makes
/// this a game you play rather than a deck you turn over, and it costs nothing
/// in grading: every individual ball is still one `DrillQuestion` graded by
/// `ShotAdvisor` exactly as before.
///
/// **There is a clock.** Shot selection under no time pressure is a different
/// skill from shot selection, and the app was training the wrong one.
struct DrillSessionView: View {
    let phase: RallyPhase?
    let sessionLength: Int

    @EnvironmentObject private var subscriptions: SubscriptionService
    @EnvironmentObject private var progress: ProgressStore
    @StateObject private var records = PracticeRecordStore.shared
    @EnvironmentObject private var limiter: PracticeLimiter
    @EnvironmentObject private var reviews: ReviewPromptTracker
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    @State private var balls: [RallyBall] = []
    @State private var index = 0
    @State private var picked: Int?
    @State private var timedOut = false
    @State private var correctCount = 0
    @State private var answeredCount = 0
    @State private var yourPoints = 0
    @State private var theirPoints = 0
    @State private var showPaywall = false
    @State private var showAbandonConfirmation = false
    @State private var finished = false
    @State private var stoppedAtFreeLimit = false
    @State private var recordedSession = false
    /// Seconds left on the shot clock, or nil when the clock is off or the ball
    /// has already been graded.
    @State private var clockRemaining: Double?

    private let tick = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    init(phase: RallyPhase? = nil, sessionLength: Int = 12) {
        self.phase = phase
        self.sessionLength = sessionLength
    }

    var body: some View {
        Group {
            if finished {
                RallySummaryView(
                    yourPoints: yourPoints,
                    theirPoints: theirPoints,
                    correct: correctCount,
                    answered: answeredCount,
                    stoppedAtFreeLimit: stoppedAtFreeLimit,
                    recommendation: progress.recommendation,
                    onSeePro: { showPaywall = true },
                    onDone: { dismiss() }
                )
            } else if let ball = balls[safe: index] {
                court(ball)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.background)
                    .onAppear(perform: build)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .toolbar(finished ? .visible : .hidden, for: .navigationBar)
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .confirmationDialog(
            "Leave this session?",
            isPresented: $showAbandonConfirmation,
            titleVisibility: .visible
        ) {
            Button("Leave, keep my \(answeredCount) balls", role: .destructive) {
                endSession(atFreeLimit: false)
                dismiss()
            }
            Button("Keep playing", role: .cancel) { }
        } message: {
            Text("The balls you've already answered are recorded. The rest of this session is discarded.")
        }
        .onAppear { if balls.isEmpty { build() } }
        .onReceive(tick) { _ in advanceClock() }
    }

    // MARK: - The court

    /// One full-bleed layer of court, with everything else floating over it.
    private func court(_ ball: RallyBall) -> some View {
        ZStack {
            CourtPOVView(
                position: ball.position,
                options: ball.question.options,
                aimPoints: aimPoints(for: ball),
                phase: povPhase(for: ball),
                onPick: picked == nil ? { select($0, in: ball) } : nil
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                hud(ball)
                Spacer(minLength: 0)
            }

            VStack(spacing: 0) {
                Spacer(minLength: 0)
                if picked != nil || timedOut {
                    // The card runs to the physical bottom of the screen. Left
                    // inside the safe area it floated with a band of court
                    // showing under it, which read as a sheet that had not
                    // finished animating in.
                    VerdictCard(
                        ball: ball,
                        picked: picked,
                        timedOut: timedOut,
                        buttonTitle: nextButtonTitle,
                        onNext: advance
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    prompt(ball)
                }
            }
            .ignoresSafeArea(edges: .bottom)
        }
        // The one animation on this screen, and it moves only the card. The
        // court underneath is untouched, which is the entire point.
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: picked)
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: timedOut)
        .background(Theme.Surface.apron)
        // The court runs edge to edge under a dark sky, and the app's default
        // appearance is light, so iOS drew the clock and the battery in
        // near-black on near-black at the top of every ball. `.preferredColorScheme`
        // does not reach the status bar from a pushed view, and there is no
        // light band up there to put dark glyphs on. The screen is a game
        // screen with its own scoreboard, shot counter and clock, so it takes
        // the whole display and gives the state back in the HUD.
        .statusBarHidden(true)
    }

    private func povPhase(for ball: RallyBall) -> CourtPOVView.Phase {
        guard picked != nil || timedOut else { return .deciding }
        return .graded(picked: picked ?? -1, answer: ball.question.answerIndex)
    }

    private func aimPoints(for ball: RallyBall) -> [CourtPoint] {
        ShotAiming.aimPoints(
            for: ball.question.options,
            in: ball.position,
            answer: ball.question.answer,
            answerTarget: ball.question.verdict.targetOpponent
        )
    }

    // MARK: - HUD

    private func hud(_ ball: RallyBall) -> some View {
        VStack(spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                Button(action: leave) {
                    Image(systemName: "chevron.left")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(.black.opacity(0.45), in: Circle())
                }
                .accessibilityLabel("Back")
                .accessibilityIdentifier("nav-back")

                scoreboard(ball)

                Spacer(minLength: 0)

                if let clockRemaining, let total = settings.shotClock.seconds {
                    ShotClockRing(remaining: clockRemaining, total: total)
                }
            }
            .padding(.horizontal, 14)
            // Capped and centred, or the scoreboard and the shot clock end up
            // at opposite corners of a 13 inch iPad with three feet of court
            // between them.
            .frame(maxWidth: Theme.readableContentWidth)
            .frame(maxWidth: .infinity)

            HStack(spacing: 10) {
                Text(ball.position.phase.title.uppercased())
                    .font(.caption2.weight(.heavy))
                    .kerning(1.2)
                Text("SHOT \(ball.shotIndex + 1) OF \(ball.shotsInPoint)")
                    .font(.caption2.weight(.heavy))
                    .kerning(1.2)
                    .opacity(0.75)
                Spacer(minLength: 0)
                if !subscriptions.isPro {
                    Label("\(limiter.remaining(isPro: false))", systemImage: "circle.dashed")
                        .font(.caption2.weight(.bold))
                        .accessibilityLabel("\(limiter.remaining(isPro: false)) free balls left today")
                }
            }
            .foregroundStyle(.white.opacity(0.9))
            .padding(.horizontal, 16)
            .frame(maxWidth: Theme.readableContentWidth)
            .frame(maxWidth: .infinity)
        }
        .padding(.top, 4)
        .padding(.bottom, 10)
        .background(
            LinearGradient(
                colors: [.black.opacity(0.55), .black.opacity(0)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea(edges: .top)
        )
    }

    private func scoreboard(_ ball: RallyBall) -> some View {
        HStack(spacing: 6) {
            Text("\(yourPoints)")
                .foregroundStyle(Theme.Surface.ball)
            Text("–").opacity(0.5)
            Text("\(theirPoints)")
                .foregroundStyle(.white)
        }
        .font(Theme.numeric(19, weight: .heavy))
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .background(.black.opacity(0.45), in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Score, you \(yourPoints), them \(theirPoints)")
    }

    /// The question, stated as a question and nothing else.
    ///
    /// The old screen printed the ball height and the contact side here in
    /// words, which handed over the two facts the answer turns on. Now they are
    /// in the render, where they have to be read.
    private func prompt(_ ball: RallyBall) -> some View {
        Text("Where do you hit it?")
            .font(Theme.display(20))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(.black.opacity(0.5), in: Capsule())
            .padding(.bottom, 26)
            .accessibilityAddTraits(.isHeader)
    }

    private var nextButtonTitle: String {
        if isLastBall { return "Finish" }
        guard let ball = balls[safe: index] else { return "Next" }
        let lostPoint = picked != ball.question.answerIndex
        return (lostPoint || ball.isLastOfPoint) ? "Next point" : "Next shot"
    }

    private var isLastBall: Bool {
        guard let ball = balls[safe: index] else { return true }
        let lostPoint = picked != ball.question.answerIndex
        if lostPoint || ball.isLastOfPoint {
            return RallyBuilder.firstBall(after: ball.pointIndex, in: balls) == nil
        }
        return index + 1 >= balls.count
    }

    // MARK: - Clock

    private func startClock() {
        clockRemaining = settings.shotClock.seconds
    }

    private func advanceClock() {
        guard picked == nil, !timedOut, !finished,
              let remaining = clockRemaining else { return }
        let next = remaining - 0.05
        if next <= 0 {
            clockRemaining = 0
            expire()
        } else {
            clockRemaining = next
        }
    }

    /// The clock ran out. Graded as a miss, because on a court a ball you did
    /// not decide about is a ball you did not hit, and recorded honestly rather
    /// than quietly skipped.
    private func expire() {
        guard let ball = balls[safe: index] else { return }
        limiter.rollOverIfNeeded()
        guard limiter.canPractice(isPro: subscriptions.isPro) else {
            endSession(atFreeLimit: true)
            return
        }
        timedOut = true
        answeredCount += 1
        theirPoints += 1
        Haptics.wrongAnswer()
        progress.record(
            phase: ball.position.phase,
            wasCorrect: false,
            principle: ball.question.verdict.principle
        )
        records.record(
            itemID: ball.position.phase.itemPrefix + ball.position.id,
            courtID: ball.position.phase.courtID,
            correct: false,
            isReviewable: false
        )
        limiter.consume(isPro: subscriptions.isPro)
    }

    // MARK: - Flow

    private func build() {
        let allowance = limiter.remaining(isPro: subscriptions.isPro)
        let budget = max(1, min(sessionLength, allowance))
        balls = RallyBuilder.session(ballBudget: budget, seed: drillSeed(), phase: phase)
        startClock()
    }

    private func drillSeed() -> UInt64 {
        #if DEBUG
        // A screenshot has to be the same court every run, or the App Store
        // asset is whatever the clock happened to say.
        if let fixed = DebugFixtures.requestedSeed { return fixed }
        #endif
        return UInt64(Date().timeIntervalSince1970)
    }

    private func select(_ offset: Int, in ball: RallyBall) {
        // A session can straddle midnight. Roll over here, in an event handler
        // rather than a view body, so the cap the tap is graded against is
        // today's cap and not the one this screen was built with.
        limiter.rollOverIfNeeded()
        guard limiter.canPractice(isPro: subscriptions.isPro) else {
            endSession(atFreeLimit: true)
            return
        }
        clockRemaining = nil
        picked = offset
        let wasCorrect = offset == ball.question.answerIndex
        if wasCorrect {
            correctCount += 1
            if ball.isLastOfPoint { yourPoints += 1 }
            Haptics.correctAnswer()
        } else {
            theirPoints += 1
            Haptics.wrongAnswer()
        }
        answeredCount += 1
        progress.record(
            phase: ball.position.phase,
            wasCorrect: wasCorrect,
            principle: ball.question.verdict.principle
        )
        // A generated position's id is a one-off, so the store rolls every ball
        // in a phase onto one row; the MISTAKE is what comes back, not the
        // question.
        records.record(
            itemID: ball.position.phase.itemPrefix + ball.position.id,
            courtID: ball.position.phase.courtID,
            correct: wasCorrect,
            isReviewable: false
        )
        if !wasCorrect,
           let pattern = MistakeCatalog.pattern(
               for: ball.question.options[offset], in: ball.position
           ) {
            records.recordMistake(pattern)
        }
        limiter.consume(isPro: subscriptions.isPro)
    }

    private func advance() {
        guard let ball = balls[safe: index] else {
            endSession(atFreeLimit: false)
            return
        }
        let lostPoint = timedOut || picked != ball.question.answerIndex

        limiter.rollOverIfNeeded()
        guard limiter.canPractice(isPro: subscriptions.isPro) else {
            endSession(atFreeLimit: true)
            return
        }

        let next: Int?
        if lostPoint {
            // The rally is dead. Playing out the rest of a point you already
            // lost is the flashcard behaviour this model exists to remove.
            next = RallyBuilder.firstBall(after: ball.pointIndex, in: balls)
        } else if ball.isLastOfPoint {
            next = RallyBuilder.firstBall(after: ball.pointIndex, in: balls)
        } else {
            next = index + 1 < balls.count ? index + 1 : nil
        }

        guard let next else {
            endSession(atFreeLimit: false)
            return
        }
        picked = nil
        timedOut = false
        index = next
        startClock()
    }

    /// One place that closes a session, so the history, the review counter and
    /// the free-limit state can never disagree about whether it happened.
    private func endSession(atFreeLimit: Bool) {
        clockRemaining = nil
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

/// The shot clock, as a ring that drains.
///
/// A ring rather than a number because it has to be readable in peripheral
/// vision while the player is looking at the far kitchen. It turns from optic
/// yellow to the wrong-answer red over the last third, so urgency arrives
/// before the number would have been read.
struct ShotClockRing: View {
    let remaining: Double
    let total: Double

    private var fraction: Double { max(0, min(1, remaining / max(total, 0.01))) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.25), lineWidth: 4)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(
                    fraction < 0.34 ? Theme.wrongRed : Theme.Surface.ball,
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            Text("\(Int(remaining.rounded(.up)))")
                .font(Theme.numeric(15, weight: .heavy))
                .foregroundStyle(.white)
        }
        .frame(width: 40, height: 40)
        .accessibilityLabel("\(Int(remaining.rounded(.up))) seconds left")
    }
}

/// The verdict, as a card that slides up OVER the court.
///
/// It overlays rather than inserting into a stack on purpose: an inserted card
/// pushes everything below it down the screen, which is what made answering a
/// ball feel like the app had lost its place. Here the court behind it is
/// untouched and still shows the rings, so the explanation and the thing it is
/// explaining are on screen together.
struct VerdictCard: View {
    /// The card ignores the bottom safe area so no court shows under it, which
    /// means the button has to keep clear of the home indicator itself.
    static let homeIndicatorClearance: CGFloat = 22

    let ball: RallyBall
    let picked: Int?
    let timedOut: Bool
    let buttonTitle: String
    let onNext: () -> Void

    @State private var showsOverhead = false

    private var wasCorrect: Bool { !timedOut && picked == ball.question.answerIndex }
    private var verdict: ShotVerdict { ball.question.verdict }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(verdict.best.label)
                        .font(Theme.display(23))
                        .foregroundStyle(Theme.ink)

                    if let target = verdict.targetOpponent {
                        Label("Aimed at \(target.label), marked \(target.marker)",
                              systemImage: "scope")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(Theme.inkSecondary)
                    }

                    Label(verdict.principle, systemImage: "lightbulb.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.opticInk)

                    Text(verdict.why)
                        .font(.callout)
                        .foregroundStyle(Theme.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    // The overhead is where it belongs now: not as the way you
                    // make the decision, but as the whiteboard a coach draws on
                    // AFTER it, to show you the geometry you could not see from
                    // where you were standing.
                    DisclosureGroup(isExpanded: $showsOverhead) {
                        CourtDiagramView(
                            position: ball.position,
                            highlight: verdict.targetOpponent
                        )
                        .frame(maxWidth: 220)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                    } label: {
                        Text("Show it from above")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.court)
                    }
                    .tint(Theme.court)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 14)
            }
            // Capped so the card can never swallow the court it is explaining,
            // and capped to the same band `CourtPOVView` reserved for it: the
            // four captions sit in the near court now, and a card that grew
            // past this would cover the answer it is talking about.
            .frame(maxHeight: 210)
            // Without this the explanation is guillotined mid-word against the
            // button and nothing says it continues. The fade is the only cue
            // that the card scrolls.
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .black, location: 0),
                        .init(color: .black, location: 0.88),
                        .init(color: .black.opacity(0), location: 1),
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            )

            // The identifier goes on the Button itself, before the layout
            // modifiers. Applied after `.padding` it lands on the padded
            // container, which SwiftUI exports as an "Other" element: the
            // screenshot harness looked it up with `app.buttons["next-ball"]`,
            // found nothing, and every capture run walked exactly one ball
            // while still reporting success.
            Button(buttonTitle, action: onNext)
                .accessibilityIdentifier("next-ball")
                .primaryCTA(color: Theme.court)
                .padding(.horizontal, 18)
                .padding(.bottom, 10)
                .padding(.bottom, VerdictCard.homeIndicatorClearance)
        }
        .padding(.top, 14)
        // Reading width, centred. Full bleed on an iPad put a two-line
        // explanation on one 1000 point line, which is a paragraph nobody
        // tracks across.
        .frame(maxWidth: Theme.readableContentWidth)
        .frame(maxWidth: .infinity)
        .background(Theme.card)
        .clipShape(UnevenRoundedRectangle(
            topLeadingRadius: 26, bottomLeadingRadius: 0,
            bottomTrailingRadius: 0, topTrailingRadius: 26, style: .continuous
        ))
        .shadow(color: .black.opacity(0.35), radius: 18, y: -6)
    }

    /// The identifier lives on the headline, not on the whole card.
    ///
    /// An identifier applied to a container is inherited by every view inside
    /// it, and the inherited one WINS: with `answer-card` on the card, the
    /// primary button reported `answer-card` too and `next-ball` did not exist
    /// anywhere in the tree. Every capture run walked exactly one ball and then
    /// gave up, while still reporting success.
    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: wasCorrect ? "checkmark.circle.fill"
                                         : (timedOut ? "clock.badge.xmark.fill" : "xmark.circle.fill"))
            Text(headline)
            Spacer(minLength: 0)
        }
        .font(.subheadline.weight(.heavy))
        .foregroundStyle(wasCorrect ? Theme.rightGreen : Theme.wrongRed)
        .padding(.horizontal, 18)
        .padding(.bottom, 10)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("answer-card")
    }

    private var headline: String {
        if timedOut { return "Too slow. Point to them." }
        if wasCorrect {
            return ball.isLastOfPoint ? "Point won." : "Good. Rally continues."
        }
        return "Point to them."
    }
}

/// How the session ended: the score first, because the session was a game.
struct RallySummaryView: View {
    let yourPoints: Int
    let theirPoints: Int
    let correct: Int
    let answered: Int
    let stoppedAtFreeLimit: Bool
    let recommendation: (phase: RallyPhase, isMeasured: Bool)?
    let onSeePro: () -> Void
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("\(yourPoints) – \(theirPoints)")
                .font(Theme.numeric(56, weight: .heavy))
                .foregroundStyle(Theme.ink)
                .accessibilityLabel("Final score, you \(yourPoints), them \(theirPoints)")
            Text(blurb)
                .font(.headline)
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
            Text("\(correct) of \(max(answered, 1)) shots were the right call.")
                .font(.subheadline)
                .foregroundStyle(Theme.inkSecondary)

            if stoppedAtFreeLimit {
                VStack(spacing: 8) {
                    Text("That's your \(PracticeLimiter.freeDailyBalls) free balls for today.")
                        .font(.subheadline.weight(.semibold))
                        .multilineTextAlignment(.center)
                    Text("The counter resets tomorrow. Pro removes it entirely.")
                        .font(.footnote)
                        .foregroundStyle(Theme.inkSecondary)
                        .multilineTextAlignment(.center)
                    Button("See Pro", action: onSeePro)
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("summary-paywall")
                }
                .padding(.top, 4)
            } else if let recommendation {
                Text(recommendation.isMeasured
                     ? "Next up: \(recommendation.phase.title.lowercased()) is your weakest phase."
                     : "Next up: try \(recommendation.phase.title.lowercased()), which you haven't played yet.")
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSecondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
            Button("Done", action: onDone)
                .accessibilityIdentifier("session-done")
                .primaryCTA(color: Theme.court)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }

    private var blurb: String {
        let denom = max(answered, 1)
        let ratio = Double(correct) / Double(denom)
        switch ratio {
        case 0.9...: return "That's tournament-grade shot selection."
        case 0.7..<0.9: return "Solid. The misses are where the rating is."
        case 0.5..<0.7: return "Middle of the pack. Read their feet before you swing."
        default: return "This is the phase to live in for a week."
        }
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
