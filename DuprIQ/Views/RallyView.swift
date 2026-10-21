import StoreKit
import SwiftUI

/// The app. You are on the court, the ball is coming, and you pick where it
/// goes.
///
/// **The court never moves.** It is a fixed, full-bleed layer and everything
/// else is an overlay on it, so grading a ball swaps the option panel for the
/// verdict card without anything reflowing.
///
/// **A point is a rally, not a card.** A right decision advances the same
/// point to your next shot; a wrong one loses it. Every third point is a focus
/// point aimed at whatever has been costing you the most.
///
/// **Every graded ball is replayed.** Your shot and the right one fly from the
/// contact in the 3D court, so a miss is something you watch go wrong rather
/// than a red row.
struct RallyView: View {
    static let pointsPerRun = 12

    @EnvironmentObject private var subscriptions: SubscriptionService
    @EnvironmentObject private var mastery: MasteryStore
    @EnvironmentObject private var limiter: PracticeLimiter
    @EnvironmentObject private var reviews: ReviewPromptTracker
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var profile: PlayerProfile
    @Environment(\.requestReview) private var requestReview
    @Environment(\.scenePhase) private var scenePhase

    @State private var balls: [RallyBall] = []
    @State private var index = 0
    @State private var picked: Int?
    @State private var timedOut = false
    @State private var correctCount = 0
    @State private var answeredCount = 0
    @State private var yourPoints = 0
    @State private var theirPoints = 0
    @State private var replayToken = 0
    /// The verdict card opened to its full explanation.
    @State private var cardExpanded = false
    /// The height the card asks for to show everything without scrolling.
    @State private var cardFitHeight: CGFloat = 0
    @State private var showPaywall = false
    @State private var showYourGame = false
    @State private var finished = false
    @State private var stoppedAtFreeLimit = false
    @State private var recordedRun = false
    /// Seconds left on the shot clock, or nil when the clock is off or the ball
    /// has already been graded.
    @State private var clockRemaining: Double?
    /// When the clock last ticked: the timer publisher drifts under load, so
    /// the clock spends real elapsed time, not a fixed 0.05 s per tick.
    @State private var clockLastTick: Date?

    private let tick = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if finished {
                RallySummaryView(
                    yourPoints: yourPoints,
                    theirPoints: theirPoints,
                    correct: correctCount,
                    answered: answeredCount,
                    stoppedAtFreeLimit: stoppedAtFreeLimit,
                    nextFocus: nextFocusLine,
                    onSeePro: { showPaywall = true },
                    onYourGame: { showYourGame = true },
                    onPlayAgain: playAgain
                )
            } else if let ball = balls[safe: index] {
                court(ball)
            } else {
                Theme.Surface.apron
                    .ignoresSafeArea()
                    .onAppear(perform: build)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showPaywall) { PaywallView(source: "rally").pageSizedOnIPad() }
        .sheet(isPresented: $showYourGame) { YourGameView().pageSizedOnIPad() }
        .onReceive(tick) { _ in advanceClock() }
        // A replay that ran while "Your game" covered the court, or while the
        // app was in the background, was never seen: fly it again.
        .onChange(of: showYourGame) { _, open in
            if !open && isGraded && !finished { replayToken += 1 }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            // Time in the background does not count against the shot clock.
            clockLastTick = .now
            if isGraded && !finished { replayToken += 1 }
        }
        .onChange(of: subscriptions.isPro) { _, isPro in
            // Buying Pro from the free-limit summary should put a ball in
            // front of you, not leave you on a "come back tomorrow" screen.
            if isPro && finished && stoppedAtFreeLimit { playAgain() }
        }
    }

    // MARK: - The court

    private func court(_ ball: RallyBall) -> some View {
        GeometryReader { geo in
            // The full-bleed height, which is what `CourtPOVView` reserved its
            // option band against.
            let full = CGSize(
                width: geo.size.width,
                height: geo.size.height + geo.safeAreaInsets.top + geo.safeAreaInsets.bottom
            )
            courtBody(ball, band: CourtPOVView.verdictCardHeight(in: full), screenHeight: full.height)
        }
    }

    private func courtBody(_ ball: RallyBall, band: CGFloat, screenHeight: CGFloat) -> some View {
        ZStack {
            CourtPOVView(
                position: ball.position,
                options: ball.question.options,
                aimPoints: aimPoints(for: ball),
                phase: povPhase(for: ball),
                onPick: isGraded ? nil : { select($0, in: ball) },
                prompt: "Choose where to hit it",
                replay: replayFlights(for: ball),
                replayToken: replayToken
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                hud(ball)
                Spacer(minLength: 0)
            }

            VStack(spacing: 0) {
                Spacer(minLength: 0)
                if isGraded {
                    VerdictCard(
                        ball: ball,
                        picked: picked,
                        timedOut: timedOut,
                        buttonTitle: nextButtonTitle,
                        isExpanded: $cardExpanded,
                        onFitHeight: { cardFitHeight = $0 },
                        onReplay: {
                            // The replay is the court; an open card would hide it.
                            withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) { cardExpanded = false }
                            replayToken += 1
                        },
                        onNext: advance
                    )
                    .frame(height: cardHeight(band: band, screenHeight: screenHeight), alignment: .top)
                    .clipped()
                    // Opaque and sliding, not fading: half-faded over the
                    // option panel, both sets of text printed through.
                    .transition(.move(edge: .bottom))
                }
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: picked)
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: timedOut)
        .background(Theme.Surface.apron)
        // A game screen with its own scoreboard and clock; the system status
        // bar would draw dark glyphs on a dark sky.
        .statusBarHidden(true)
    }

    private var isGraded: Bool { picked != nil || timedOut }

    /// Closed, the card fits the option band it replaced. Open, it grows to
    /// its text, up to the point where the court would stop reading as one.
    private func cardHeight(band: CGFloat, screenHeight: CGFloat) -> CGFloat {
        guard cardExpanded else { return band }
        return min(max(band, cardFitHeight), screenHeight * 0.7)
    }

    private func povPhase(for ball: RallyBall) -> CourtPOVView.Phase {
        guard isGraded else { return .deciding }
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

    /// Your shot first, in red, then the right one in green. A right answer
    /// replays once, in green.
    private func replayFlights(for ball: RallyBall) -> [CourtPOVView.Replay] {
        guard isGraded else { return [] }
        let points = aimPoints(for: ball)
        let contactHeight = CourtScene.ballHeight(ball.position.ballHeight)
        func flight(_ option: Int, intoNet: Bool) -> ShotFlight? {
            guard let shot = ball.question.options[safe: option],
                  let landing = points[safe: option] else { return nil }
            return ShotFlight.make(
                shot, from: ball.position.contact, contactHeight: contactHeight,
                to: landing, intoNet: intoNet
            )
        }
        var flights: [CourtPOVView.Replay] = []
        if let picked, picked != ball.question.answerIndex,
           let shot = ball.question.options[safe: picked] {
            let netted = MistakeCatalog.pattern(for: shot, in: ball.question)?.id == "attacked-a-low-ball"
            if let wrong = flight(picked, intoNet: netted) {
                flights.append(.init(flight: wrong, isCorrect: false))
            }
        }
        if let right = flight(ball.question.answerIndex, intoNet: false) {
            flights.append(.init(flight: right, isCorrect: true))
        }
        return flights
    }

    // MARK: - HUD

    private func hud(_ ball: RallyBall) -> some View {
        VStack(spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                Button { showYourGame = true } label: {
                    Image(systemName: "chart.bar.fill")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(.black.opacity(0.45), in: Circle())
                }
                .accessibilityLabel("Your game")
                .accessibilityIdentifier("your-game")

                scoreboard

                Spacer(minLength: 0)

                if let clockRemaining, let total = settings.shotClock.seconds {
                    ShotClockRing(remaining: clockRemaining, total: total)
                }
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: Theme.readableContentWidth)
            .frame(maxWidth: .infinity)

            HStack(spacing: 10) {
                if let focus = ball.focus {
                    Label(focusTitle(focus), systemImage: "scope")
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(Theme.Surface.ball)
                        .accessibilityIdentifier("focus-ball")
                } else {
                    Text(ball.position.phase.title.uppercased())
                        .font(.caption2.weight(.heavy))
                        .kerning(1.2)
                    Text("SHOT \(ball.shotIndex + 1) OF \(ball.shotsInPoint)")
                        .font(.caption2.weight(.heavy))
                        .kerning(1.2)
                        .opacity(0.75)
                }
                Spacer(minLength: 0)
                if !subscriptions.isPro {
                    Text("\(limiter.remaining(isPro: false)) free left")
                        .font(.caption2.weight(.heavy))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.45), in: Capsule())
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

    private func focusTitle(_ focus: RallyFocus) -> String {
        let what = focus.mistakeID.map(MistakeCatalog.title(for:)) ?? focus.phase.title
        return "FOCUS · \(what.uppercased())"
    }

    private var scoreboard: some View {
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

    private var nextFocusLine: String? {
        guard let focus = mastery.focus(for: profile.level).first else { return nil }
        if let id = focus.mistakeID {
            return "Next run leans on \(MistakeCatalog.title(for: id).lowercased())."
        }
        return "Next run leans on the \(focus.phase.title.lowercased())."
    }

    // MARK: - Clock

    private func startClock() {
        clockRemaining = settings.shotClock.seconds
        clockLastTick = .now
    }

    private func advanceClock() {
        guard let remaining = clockRemaining else { return }
        let now = Date.now
        let last = clockLastTick ?? now
        clockLastTick = now
        // Paused while "Your game" covers the court: the time does not count.
        guard !isGraded, !finished, !showYourGame else { return }
        let next = remaining - now.timeIntervalSince(last)
        if next <= 0 {
            clockRemaining = nil
            expire()
        } else {
            clockRemaining = next
        }
    }

    /// When the optional timer is on, an unanswered ball is a miss.
    private func expire() {
        guard let ball = balls[safe: index] else { return }
        limiter.rollOverIfNeeded()
        guard limiter.canPractice(isPro: subscriptions.isPro) else {
            endRun(atFreeLimit: true)
            return
        }
        timedOut = true
        answeredCount += 1
        theirPoints += 1
        Haptics.wrongAnswer()
        mastery.record(ball.question, picked: nil, focus: ball.focus?.mistakeID)
        limiter.consume(isPro: subscriptions.isPro)
        replayToken += 1
    }

    // MARK: - Flow

    private func build() {
        let allowance = limiter.remaining(isPro: subscriptions.isPro)
        guard allowance > 0 else {
            stoppedAtFreeLimit = true
            recordedRun = true
            finished = true
            return
        }
        balls = RallyBuilder.session(
            ballBudget: min(Self.pointsPerRun, allowance),
            seed: runSeed(),
            focus: mastery.focus(for: profile.level),
            half: profile.half
        )
        startClock()
    }

    private func runSeed() -> UInt64 {
        #if DEBUG
        // A screenshot has to be the same court every run.
        if let fixed = DebugFixtures.requestedSeed { return fixed }
        #endif
        return UInt64(Date().timeIntervalSince1970)
    }

    private func playAgain() {
        balls = []
        index = 0
        picked = nil
        timedOut = false
        cardExpanded = false
        correctCount = 0
        answeredCount = 0
        yourPoints = 0
        theirPoints = 0
        stoppedAtFreeLimit = false
        recordedRun = false
        finished = false
        build()
    }

    private func select(_ offset: Int, in ball: RallyBall) {
        // A run can straddle midnight; grade against today's cap.
        limiter.rollOverIfNeeded()
        guard limiter.canPractice(isPro: subscriptions.isPro) else {
            endRun(atFreeLimit: true)
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
        mastery.record(ball.question, picked: offset, focus: ball.focus?.mistakeID)
        limiter.consume(isPro: subscriptions.isPro)
        replayToken += 1
    }

    private func advance() {
        guard let ball = balls[safe: index] else {
            endRun(atFreeLimit: false)
            return
        }
        let lostPoint = timedOut || picked != ball.question.answerIndex

        limiter.rollOverIfNeeded()
        guard limiter.canPractice(isPro: subscriptions.isPro) else {
            endRun(atFreeLimit: true)
            return
        }

        let next: Int?
        if lostPoint || ball.isLastOfPoint {
            next = RallyBuilder.firstBall(after: ball.pointIndex, in: balls)
        } else {
            next = index + 1 < balls.count ? index + 1 : nil
        }

        guard let next else {
            endRun(atFreeLimit: false)
            return
        }
        // The next ball replaces this one outright. Animated, the SceneKit
        // court swaps at once while the SwiftUI badges, labels and HUD text
        // interpolate from the old position for a few frames, which read as a
        // glitch.
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) {
            picked = nil
            timedOut = false
            cardExpanded = false
            index = next
        }
        startClock()
    }

    /// One place that closes a run, so the history, the review counter and
    /// the free-limit state can never disagree about whether it happened.
    private func endRun(atFreeLimit: Bool) {
        clockRemaining = nil
        stoppedAtFreeLimit = atFreeLimit
        if !recordedRun {
            recordedRun = true
            mastery.recordRally(
                won: yourPoints, lost: theirPoints,
                answered: answeredCount, correct: correctCount
            )
            if answeredCount > 0 {
                reviews.recordSessionFinished()
                if reviews.shouldRequestReview {
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 1_400_000_000)
                        guard finished else { return }
                        reviews.markPrompted()
                        requestReview()
                    }
                }
            }
        }
        finished = true
    }
}

/// The shot clock, as a ring that drains. Readable in peripheral vision while
/// the player is looking at the far kitchen; it turns red over the last third.
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

/// The verdict, as a card that slides up over the option panel's band, so the
/// court above it (and the replay running on it) is never covered.
struct VerdictCard: View {
    /// The card ignores the bottom safe area, so the buttons keep clear of the
    /// home indicator themselves.
    static let homeIndicatorClearance: CGFloat = 22

    let ball: RallyBall
    let picked: Int?
    let timedOut: Bool
    let buttonTitle: String
    @Binding var isExpanded: Bool
    /// The card's height with every line of the explanation showing.
    let onFitHeight: (CGFloat) -> Void
    let onReplay: () -> Void
    let onNext: () -> Void

    @State private var showsOverhead = false
    @State private var cardHeight: CGFloat = 0
    @State private var viewportHeight: CGFloat = 0
    @State private var contentHeight: CGFloat = 0

    private var wasCorrect: Bool { !timedOut && picked == ball.question.answerIndex }
    private var verdict: ShotVerdict { ball.question.verdict }

    private var mistake: MistakePattern? {
        guard !wasCorrect, let picked, let shot = ball.question.options[safe: picked] else { return nil }
        return MistakeCatalog.pattern(for: shot, in: ball.question)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            grabber
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(verdict.best.label)
                        .font(Theme.display(23))
                        .foregroundStyle(Theme.ink)

                    if let mistake {
                        Text(mistake.summary)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(Theme.wrongRed)
                            .fixedSize(horizontal: false, vertical: true)
                    }

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

                    // The overhead is the whiteboard a coach draws on after
                    // the point, showing geometry you could not see from where
                    // you were standing.
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
                            .foregroundStyle(Theme.courtLight)
                    }
                    .tint(Theme.courtLight)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 44)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: {
                    contentHeight = $0
                    reportFit()
                }
                // Closed, the explanation is a few lines behind a fade. A tap
                // anywhere on it opens the card rather than asking for a
                // scroll in a strip that small.
                .contentShape(Rectangle())
                .simultaneousGesture(TapGesture().onEnded { if !isExpanded { setExpanded(true) } })
            }
            .frame(minHeight: 90)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: {
                viewportHeight = $0
                reportFit()
            }
            // Text scrolling under the buttons fades out instead of being cut
            // mid-line, which read as a layout bug.
            .mask(
                VStack(spacing: 0) {
                    Color.black
                    LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                        .frame(height: 18)
                }
            )
            .scrollIndicators(.visible)
            .accessibilityHint("Scroll for the full explanation")

            HStack(spacing: 10) {
                Button(action: onReplay) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 56, height: 56)
                        .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .accessibilityLabel("Replay the shots")
                .accessibilityIdentifier("replay")
                .buttonStyle(PressableCTAStyle())

                // The identifier goes on the Button itself; on a container it
                // is inherited by everything inside and the button vanishes
                // from the accessibility tree.
                Button(action: onNext) {
                    Text(buttonTitle).primaryCTA(color: Theme.court)
                }
                .accessibilityIdentifier("next-ball")
                .buttonStyle(PressableCTAStyle())
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 10)
            .padding(.bottom, VerdictCard.homeIndicatorClearance)
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: {
            cardHeight = $0
            reportFit()
        }
        .frame(maxWidth: Theme.readableContentWidth)
        .frame(maxWidth: .infinity)
        .background(Theme.card)
        .clipShape(UnevenRoundedRectangle(
            topLeadingRadius: 26, bottomLeadingRadius: 0,
            bottomTrailingRadius: 0, topTrailingRadius: 26, style: .continuous
        ))
        .shadow(color: .black.opacity(0.35), radius: 18, y: -6)
    }

    private func setExpanded(_ open: Bool) {
        guard open != isExpanded else { return }
        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) { isExpanded = open }
    }

    /// Everything but the scrolling strip stays the same size, so the card
    /// that shows every line is the current card plus what is scrolled away.
    private func reportFit() {
        guard cardHeight > 0, viewportHeight > 0 else { return }
        onFitHeight((cardHeight - viewportHeight + contentHeight).rounded(.up))
    }

    /// The handle a sheet has, so the card reads as one that pulls up.
    private var grabber: some View {
        Capsule()
            .fill(.white.opacity(0.22))
            .frame(width: 36, height: 5)
            .frame(maxWidth: .infinity)
            .padding(.top, 6)
            .padding(.bottom, 6)
            .contentShape(Rectangle())
            .onTapGesture { setExpanded(!isExpanded) }
            .gesture(pull)
            .accessibilityHidden(true)
    }

    private var pull: some Gesture {
        DragGesture(minimumDistance: 12).onEnded { drag in
            if drag.translation.height < -24 { setExpanded(true) }
            if drag.translation.height > 24 { setExpanded(false) }
        }
    }

    /// The identifier lives on the headline, not on the whole card.
    private var header: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: wasCorrect ? "checkmark.circle.fill"
                                             : (timedOut ? "clock.badge.xmark.fill" : "xmark.circle.fill"))
                Text(headline)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("answer-card")
            Spacer(minLength: 0)
            if showsLegend { legend }
            Button { setExpanded(!isExpanded) } label: {
                Image(systemName: "chevron.up")
                    .font(.footnote.weight(.heavy))
                    .foregroundStyle(Theme.inkSecondary)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    .frame(width: 30, height: 26)
                    .background(.white.opacity(0.08), in: Capsule())
            }
            .accessibilityLabel(isExpanded ? "Show less" : "Show the full explanation")
            .accessibilityIdentifier("expand-why")
        }
        .font(.subheadline.weight(.heavy))
        .foregroundStyle(wasCorrect ? Theme.rightGreen : Theme.wrongRed)
        .padding(.horizontal, 18)
        .padding(.bottom, 10)
        .contentShape(Rectangle())
        .gesture(pull)
    }

    /// Two flights only when you picked a wrong shot; a miss on time and a
    /// right answer fly one.
    private var showsLegend: Bool { !wasCorrect && !timedOut && picked != nil }

    /// Matches the trails on the court: yours sparse, the best one solid.
    private var legend: some View {
        HStack(spacing: 10) {
            HStack(spacing: 4) {
                Circle()
                    .strokeBorder(Theme.wrongRed, style: StrokeStyle(lineWidth: 1.5, dash: [2, 2]))
                    .frame(width: 9, height: 9)
                Text("You").foregroundStyle(Theme.inkSecondary)
            }
            HStack(spacing: 4) {
                Circle().fill(Theme.rightGreen).frame(width: 9, height: 9)
                Text("Best").foregroundStyle(Theme.inkSecondary)
            }
        }
        .font(.caption.weight(.bold))
        .accessibilityHidden(true)
    }

    private var headline: String {
        if timedOut { return "Time's up. Point to them." }
        if wasCorrect {
            return ball.isLastOfPoint ? "Point won." : "Good. Rally continues."
        }
        return "Point to them."
    }
}

/// How the run ended: the score first, because it was a game.
struct RallySummaryView: View {
    let yourPoints: Int
    let theirPoints: Int
    let correct: Int
    let answered: Int
    let stoppedAtFreeLimit: Bool
    let nextFocus: String?
    let onSeePro: () -> Void
    let onYourGame: () -> Void
    let onPlayAgain: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                Button(action: onYourGame) {
                    Label("Your game", systemImage: "chart.bar.fill")
                        .font(.subheadline.weight(.semibold))
                }
                .accessibilityIdentifier("summary-your-game")
                Spacer()
            }

            Spacer()

            if answered > 0 {
                Text("\(yourPoints) – \(theirPoints)")
                    .font(Theme.numeric(56, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                    .accessibilityLabel("Final score, you \(yourPoints), them \(theirPoints)")
                Text("\(correct) of \(answered) shots were the right call.")
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
            }

            if stoppedAtFreeLimit {
                VStack(spacing: 8) {
                    Text("That's today's \(PracticeLimiter.freeDailyBalls) free balls.")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.center)
                    Text("A fresh set arrives tomorrow. \(AppBrand.proName) takes the limit off.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSecondary)
                        .multilineTextAlignment(.center)
                }
            } else if let nextFocus {
                Text(nextFocus)
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSecondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            if stoppedAtFreeLimit {
                Button(action: onSeePro) {
                    Text("See \(AppBrand.proName)").primaryCTA(color: Theme.court)
                }
                .accessibilityIdentifier("summary-paywall")
                .buttonStyle(PressableCTAStyle())
            } else {
                Button(action: onPlayAgain) {
                    Text("Play another run").primaryCTA(color: Theme.court)
                }
                .accessibilityIdentifier("play-again")
                .buttonStyle(PressableCTAStyle())
            }
        }
        .padding(24)
        .frame(maxWidth: Theme.readableContentWidth)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
    }
}
