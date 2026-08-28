import SwiftUI

/// Flashcards as a swipeable deck. The grammar: tap flips the card to reveal
/// the answer; only a flipped card can be swiped. Right = "got it" (card
/// leaves the deck), left = "again" (card returns at the back). Before the
/// flip a horizontal drag rubber-bands, so the reveal always comes first.
/// Cards with a `CardChoice` add a self-test: pick Keep/Throw on the front,
/// and the flip grades you.
struct FlashcardDrillView: View {
    let drill: Drill
    let cards: [Flashcard]
    var accent: Color = Theme.court

    @EnvironmentObject private var progress: ProgressStore

    @State private var queue: [Flashcard] = []
    @State private var isFlipped = false
    @State private var drag: CGSize = .zero
    @State private var isFlinging = false
    @State private var crossedThreshold = false
    @State private var lastSwipe: SwipeRecord?
    @State private var finished = false
    @State private var choicePick: Int?
    @State private var confettiTrigger = 0
    /// Fades the departing card (and the KNEW IT / AGAIN stamp riding on it)
    /// out with the throw. Without it the card is simply yanked from the queue
    /// at commit and the verdict stamp blinks out of existence mid-flight.
    @State private var flingOpacity: Double = 1

    /// One-time teaching nudge after the first-ever flip.
    @AppStorage("duprIQ.hasSwipedDeck") private var hasSwipedDeck = false
    @State private var didHint = false

    private struct SwipeRecord {
        let card: Flashcard
        let gotIt: Bool
    }

    var body: some View {
        if finished {
            DrillCompleteView(drill: drill, score: nil, total: cards.count)
        } else {
            drillBody
                .onAppear {
                    if queue.isEmpty { queue = cards }
                }
        }
    }

    private var mastered: Int { cards.count - queue.count }

    private var drillBody: some View {
        VStack(spacing: 14) {
            header
            GeometryReader { geo in
                // A card should still look like a card. Unbounded, the deck
                // stretches to whatever height it is given, which on a 13-inch
                // iPad is a playing card two feet tall with its text marooned
                // in the middle. Cap the height to a card-ish ratio and centre
                // the deck in what is left; the capped size is also what the
                // fling distance is measured against.
                // 520pt keeps the card close to the proportions it has on a
                // phone, where the face was designed. Widening it to the full
                // readable width just spreads the same few words thinner.
                let width = min(geo.size.width, 520)
                let capped = CGSize(
                    width: width,
                    height: min(geo.size.height, width * 1.5)
                )
                deck(size: capped)
                    .frame(width: capped.width, height: capped.height)
                    .frame(width: geo.size.width, height: geo.size.height)
            }
            .padding(.horizontal, 4)
        }
        .padding()
        .frame(maxWidth: Theme.readableContentWidth)
        .frame(maxWidth: .infinity)
        .background(Theme.background)
        .overlay { ConfettiBurst(trigger: confettiTrigger, origin: .init(x: 0.5, y: 0.42)) }
        .navigationTitle(drill.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if lastSwipe != nil {
                    Button {
                        undo()
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .accessibilityLabel("Undo last answer")
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.well)
                    Capsule()
                        .fill(accent)
                        .frame(width: geo.size.width * CGFloat(mastered) / CGFloat(max(cards.count, 1)))
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: mastered)
                }
            }
            .frame(height: 8)
            Text("\(mastered) of \(cards.count) reviewed")
                .font(.footnote.weight(.medium))
                .foregroundStyle(Theme.inkSecondary)
                .monospacedDigit()
        }
    }

    // MARK: - Deck

    @ViewBuilder
    private func deck(size: CGSize) -> some View {
        let visible = Array(queue.prefix(3).enumerated())
        ZStack {
            ForEach(visible.reversed(), id: \.element.id) { slot, card in
                FlipCardFace(
                    card: card,
                    isFlipped: slot == 0 && isFlipped,
                    accent: accent,
                    choicePick: slot == 0 ? choicePick : nil,
                    onChoose: slot == 0 ? { choose($0, card: card) } : nil,
                    onAdvance: slot == 0 && choicePick != nil
                        ? { fling(direction: 1, size: size) }
                        : nil,
                    // Visible equivalents for the swipe. VoiceOver, Switch
                    // Control and anyone who never discovers a horizontal
                    // gesture had no way to grade a plain card at all; a hint
                    // that says "swipe right" is not an action.
                    onKnewIt: slot == 0 && card.choice == nil
                        ? { fling(direction: 1, size: size) }
                        : nil,
                    onAgain: slot == 0 && card.choice == nil
                        ? { fling(direction: -1, size: size) }
                        : nil
                )
                .scaleEffect(scale(forSlot: slot))
                .offset(y: yOffset(forSlot: slot))
                .offset(slot == 0 ? effectiveDrag : .zero)
                .rotationEffect(slot == 0 ? topRotation : .zero, anchor: .bottom)
                .overlay { if slot == 0 { verdictStamps } }
                .opacity(slot == 0 ? flingOpacity : 1)
                .zIndex(Double(3 - slot))
                .allowsHitTesting(slot == 0)
                .gesture(dragGesture(size: size))
                .accessibilityAddTraits(.isButton)
                .accessibilityHint(swipeAccessibilityHint)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Court below the front card so the stacked edges peek.
        .padding(.bottom, 26)
    }

    /// Pre-flip, horizontal pulls rubber-band: the card answers the finger but
    /// makes it obvious it won't leave until it's been flipped.
    private var effectiveDrag: CGSize {
        guard !isFlipped, !isFlinging else { return drag }
        return CGSize(width: drag.width * 0.16, height: drag.height * 0.10)
    }

    /// Once a choice card is answered, the pick is the grade. The card holds
    /// on that result until the player taps Next.
    private var choiceAnswered: Bool {
        queue.first?.choice != nil && choicePick != nil
    }

    private var swipeAccessibilityHint: String {
        guard isFlipped else { return "Tap to reveal the answer" }
        return choiceAnswered
            ? "Tap Next to continue"
            : "Use the Knew it and Again buttons, or swipe right for knew it and left to see it again"
    }

    /// KNEW IT / AGAIN stamps fade in with the drag so the swipe directions
    /// carry their meaning on the card itself, using the same words as the hint and
    /// the quick session buttons, one grading vocabulary everywhere.
    private var verdictStamps: some View {
        ZStack {
            if !choiceAnswered {
                stamp("KNEW IT", color: Theme.court, angle: -12)
                    .opacity(isFlipped ? stampOpacity(forDirection: 1) : 0)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                stamp("AGAIN", color: Theme.ball, angle: 12)
                    .opacity(isFlipped ? stampOpacity(forDirection: -1) : 0)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
        }
        .padding(22)
        .allowsHitTesting(false)
    }

    private func stamp(_ text: String, color: Color, angle: Double) -> some View {
        Text(text)
            .font(Theme.display(24, weight: .black))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(color, lineWidth: 3))
            .rotationEffect(.degrees(angle))
    }

    private func stampOpacity(forDirection direction: CGFloat) -> Double {
        let travel = drag.width * direction
        return Double(min(1, max(0, travel / 80)))
    }

    // MARK: - Stack geometry (deck physics shared with the fleet's decks)

    private func dismissDistance(_ size: CGSize) -> CGFloat {
        max(90, size.width * 0.30)
    }

    private var progress01: CGFloat {
        guard isFlipped else { return 0 }
        return min(1, abs(drag.width) / 110)
    }

    private func restingScale(_ slot: Int) -> CGFloat { 1 - CGFloat(slot) * 0.04 }
    private func restingY(_ slot: Int) -> CGFloat { CGFloat(slot) * 24 }

    private func scale(forSlot slot: Int) -> CGFloat {
        guard slot > 0 else { return 1 }
        return restingScale(slot) + (restingScale(slot - 1) - restingScale(slot)) * progress01
    }

    private func yOffset(forSlot slot: Int) -> CGFloat {
        guard slot > 0 else { return 0 }
        return restingY(slot) + (restingY(slot - 1) - restingY(slot)) * progress01
    }

    private var topRotation: Angle {
        .degrees(Double(max(-12, min(12, effectiveDrag.width / 14))))
    }

    // MARK: - Choice self-test

    private func choose(_ index: Int, card: Flashcard) {
        guard let choice = card.choice, choicePick == nil, !isFlipped, !isFlinging else { return }
        choicePick = index
        let correct = index == choice.answerIndex
        progress.recordItem(id: card.id, correct: correct)
        PracticeRecordStore.shared.record(itemID: card.id, courtID: DrillLibrary.courtID(forDrillID: drill.id), correct: correct)
        if correct {
            confettiTrigger += 1
            Haptics.correctAnswer()
            SoundPlayer.play(.success)
        } else {
            Haptics.wrongAnswer()
            SoundPlayer.play(.miss)
        }
        withAnimation(.spring(response: 0.55, dampingFraction: 0.8)) {
            isFlipped = true
        }
        maybeHintSwipe()
    }

    // MARK: - Gestures

    private func flip() {
        guard !isFlinging, !choiceAnswered else { return }
        Haptics.impact(.soft, intensity: 0.5)
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            isFlipped.toggle()
        }
        if isFlipped { maybeHintSwipe() }
    }

    private func dragGesture(size: CGSize) -> some Gesture {
        // minimumDistance 0 so the gesture also owns taps: a release that
        // barely moved flips the card (see onEnded). A separate TapGesture
        // loses the arbitration race against this drag and never fires.
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard !isFlinging else { return }
                drag = value.translation
                guard isFlipped else { return }
                let past = abs(value.translation.width) > dismissDistance(size)
                if past != crossedThreshold {
                    crossedThreshold = past
                    if past { Haptics.impact(.soft, intensity: 0.6) }
                }
            }
            .onEnded { value in
                guard !isFlinging else { return }
                crossedThreshold = false
                // A release that barely moved is a tap; the drag gesture wins
                // the race against onTapGesture, so honor the flip here too.
                if abs(value.translation.width) < 10, abs(value.translation.height) < 10 {
                    drag = .zero
                    flip()
                    return
                }
                guard isFlipped else {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                        drag = .zero
                    }
                    return
                }
                guard !choiceAnswered else {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                        drag = .zero
                    }
                    return
                }
                let dx = value.translation.width
                let flung = abs(dx) > dismissDistance(size)
                    || abs(value.predictedEndTranslation.width) > size.width * 0.75
                if flung {
                    fling(direction: dx >= 0 ? 1 : -1, size: size)
                } else {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                        drag = .zero
                    }
                }
            }
    }

    /// Throw the card off, then commit the grade with animation suppressed.
    /// the risen card behind is already in place, so nothing jumps. The card
    /// fades as it goes, so the verdict stamp leaves with it instead of being
    /// cut off the instant the queue drops the card.
    private func fling(direction: CGFloat, size: CGSize) {
        isFlinging = true
        hasSwipedDeck = true
        Haptics.impact(.rigid, intensity: 0.7)
        let exit = CGSize(width: direction * size.width * 1.5, height: drag.height * 1.1)
        withAnimation(.easeIn(duration: 0.34)) {
            drag = exit
            flingOpacity = 0
        } completion: {
            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t) {
                commit(gotIt: direction > 0)
                drag = .zero
                flingOpacity = 1
                isFlinging = false
                isFlipped = false
            }
        }
    }

    private func commit(gotIt: Bool) {
        guard let card = queue.first else { return }
        // Choice cards were graded at pick time; the swipe only advances, and
        // the graded answer (not the swipe direction) decides whether the
        // card comes back. Plain cards grade by swipe.
        let knewIt: Bool
        if let choice = card.choice, let pick = choicePick {
            knewIt = pick == choice.answerIndex
        } else {
            knewIt = gotIt
            progress.recordItem(id: card.id, correct: gotIt)
            PracticeRecordStore.shared.record(itemID: card.id, courtID: DrillLibrary.courtID(forDrillID: drill.id), correct: gotIt)
        }
        lastSwipe = SwipeRecord(card: card, gotIt: knewIt)
        choicePick = nil
        queue.removeFirst()
        if !knewIt {
            queue.append(card)
        }
        if queue.isEmpty {
            Haptics.success()
            withAnimation(.easeInOut(duration: 0.3)) { finished = true }
        }
    }

    private func undo() {
        guard let record = lastSwipe, !isFlinging else { return }
        Haptics.impact(.light)
        lastSwipe = nil
        choicePick = nil
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            if !record.gotIt, queue.last?.id == record.card.id {
                queue.removeLast()
            }
            queue.insert(record.card, at: 0)
            isFlipped = false
        }
    }

    /// One-time teaching beat: after the first-ever flip the card eases toward
    /// the edge and springs back, previewing the swipe and the rise behind it.
    private func maybeHintSwipe() {
        guard !hasSwipedDeck, !didHint, queue.count > 1 else { return }
        didHint = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard !hasSwipedDeck, !isFlinging, drag == .zero, isFlipped else { return }
            withAnimation(.spring(response: 0.38, dampingFraction: 0.6)) {
                drag = CGSize(width: 52, height: 0)
            }
            try? await Task.sleep(nanoseconds: 430_000_000)
            guard !isFlinging else { return }
            withAnimation(.spring(response: 0.55, dampingFraction: 0.72)) {
                drag = .zero
            }
        }
    }
}

// MARK: - Card faces

/// One card, both faces, flipped as a single rigid unit: the whole card
/// rotates and the face swap happens exactly at 90°, when the card is
/// edge-on and invisible. Rotating the faces inside a static background is
/// what made the text detach from the card (the Sideline deck fix).
struct FlipCardFace: View {
    let card: Flashcard
    let isFlipped: Bool
    var accent: Color = Theme.court
    var choicePick: Int?
    var onChoose: ((Int) -> Void)?
    var onAdvance: (() -> Void)? = nil
    /// Visible grading, for plain cards. The swipe stays as a shortcut.
    var onKnewIt: (() -> Void)? = nil
    var onAgain: (() -> Void)? = nil
    /// The deck grades by swipe; the mixed session grades with buttons.
    var showsSwipeHints = true

    @State private var shineTrigger = 0

    var body: some View {
        FlipRotation(angle: isFlipped ? 180 : 0) {
            front
        } back: {
            back
        }
        .shine(trigger: shineTrigger, corner: Theme.deckCorner)
        // `.contain` once the back carries its own controls, so the grading
        // buttons and the principle stay reachable instead of being folded into
        // one unactionable label.
        .accessibilityElement(children: isFlipped && backHasControls ? .contain : .combine)
        .accessibilityLabel(isFlipped ? backAccessibilityLabel : card.frontTitle)
        .task(id: isFlipped) {
            // A correct call earns the slot-machine gleam once the flip lands.
            guard isFlipped, verdict?.correct == true else { return }
            try? await Task.sleep(nanoseconds: 450_000_000)
            shineTrigger += 1
        }
    }

    private var front: some View {
        CourtCardFace(accent: accent, eyebrow: "THE COURT") {
            VStack(spacing: 18) {
                Spacer(minLength: 0)
                Text(card.frontTitle)
                    .font(Theme.display(25))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                if !card.givens.isEmpty {
                    GivensView(givens: card.givens, scale: 1.1)
                }
                if let subtitle = card.frontSubtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSecondary)
                        .multilineTextAlignment(.center)
                }
                Spacer(minLength: 0)
                if let choice = card.choice, let onChoose {
                    choiceButtons(choice, onChoose: onChoose)
                } else {
                    Label("Tap to reveal", systemImage: "hand.tap.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.inkTertiary)
                }
            }
        }
    }

    private var back: some View {
        CourtCardFace(accent: accent, eyebrow: "THE CALL") {
            VStack(spacing: 14) {
                if let verdict {
                    verdictBanner(verdict)
                }
                Spacer(minLength: 0)
                Text(card.backTitle)
                    .font(Theme.display(22))
                    .foregroundStyle(accent)
                    .multilineTextAlignment(.center)
                Rectangle()
                    .fill(Theme.rule)
                    .frame(width: 44, height: 2)
                Text(card.backBody)
                    .font(.body)
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                // The whole product promise is navigation: know the fact AND
                // know where to verify it. The card stored this all along and
                // never showed it, which quietly made the fact cards the one
                // place in the app that teaches without a principle.
                if let principle = card.principle {
                    PrincipleLabel(principle)
                }
                Spacer(minLength: 0)
                if showsSwipeHints {
                    if let onAdvance {
                        Button(action: onAdvance) {
                            Text("Next").primaryCTA(color: accent)
                        }
                    } else if onKnewIt != nil || onAgain != nil {
                        gradingButtons
                    } else {
                        Label("Knew it? Swipe right · Again? Swipe left", systemImage: "hand.draw.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.inkTertiary)
                    }
                }
            }
        }
    }

    private var backHasControls: Bool {
        onAdvance != nil || onKnewIt != nil || onAgain != nil
    }

    private var backAccessibilityLabel: String {
        var parts = ["\(card.backTitle). \(card.backBody)"]
        if let principle = card.principle {
            parts.append("Principle: \(principle).")
        }
        return parts.joined(separator: " ")
    }

    /// Swipe stays available and stays faster; these are the equivalent, not a
    /// replacement. Same two words as the stamps and the hint, so the app has
    /// one grading vocabulary.
    private var gradingButtons: some View {
        HStack(spacing: 10) {
            if let onAgain {
                Button(action: onAgain) {
                    gradeLabel("Again", systemImage: "arrow.uturn.left", color: Theme.ball)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Brings this card back later in the session")
            }
            if let onKnewIt {
                Button(action: onKnewIt) {
                    gradeLabel("Knew it", systemImage: "checkmark", color: Theme.court)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Removes this card from the session")
            }
        }
    }

    private func gradeLabel(_ title: String, systemImage: String, color: Color) -> some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(color)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
            .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .strokeBorder(color.opacity(0.45), lineWidth: 1.5)
            )
    }

    private var verdict: (text: String, correct: Bool)? {
        guard let choice = card.choice, let pick = choicePick else { return nil }
        let correct = pick == choice.answerIndex
        return ("You said \"\(choice.options[pick])\"", correct)
    }

    private func verdictBanner(_ verdict: (text: String, correct: Bool)) -> some View {
        HStack(spacing: 8) {
            Image(systemName: verdict.correct ? "checkmark.circle.fill" : "xmark.circle.fill")
            Text(verdict.correct ? "\(verdict.text). Right!" : "\(verdict.text). Not this time.")
                .font(.footnote.weight(.semibold))
        }
        .foregroundStyle(verdict.correct ? Theme.court : Theme.ball)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background((verdict.correct ? Theme.court : Theme.ball).opacity(0.13), in: Capsule())
    }

    /// Displays the two options in a deterministic, per-card shuffled order
    /// (seeded by the card id) so the answer isn't always the left/first
    /// button, but reports the ORIGINAL option index back to `onChoose` so
    /// grading stays against the authored `answerIndex` unchanged.
    private func choiceButtons(_ choice: CardChoice, onChoose: @escaping (Int) -> Void) -> some View {
        let order = ChoiceShuffle.permutation(count: choice.options.count, seed: card.id)
        return VStack(spacing: 8) {
            Text("Make the call")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.inkTertiary)
            HStack(spacing: 10) {
                ForEach(order, id: \.self) { index in
                    Button {
                        onChoose(index)
                    } label: {
                        Text(choice.options[index])
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(accent)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 44)
                            .background(accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .strokeBorder(accent.opacity(0.45), lineWidth: 1.5)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

/// Shared card chrome: ivory surface, double frame like a code-book plate,
/// corner pips, and a faint omega watermark so the open space feels designed
/// instead of empty.
private struct CourtCardFace<Content: View>: View {
    let accent: Color
    let eyebrow: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                frameDot
                Text(eyebrow)
                    .font(.caption2.weight(.heavy))
                    .kerning(2.2)
                    .foregroundStyle(accent.opacity(0.65))
                frameDot
            }
            content()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            RoundedRectangle(cornerRadius: Theme.deckCorner, style: .continuous)
                .fill(Theme.card)
        }
        .overlay {
            // Watermark sits above the surface but below the frame.
            Text("Ω")
                .font(.system(size: 190, weight: .bold))
                .foregroundStyle(accent.opacity(0.05))
                .rotationEffect(.degrees(-10))
                .offset(x: 60, y: 70)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .clipShape(RoundedRectangle(cornerRadius: Theme.deckCorner, style: .continuous))
                .allowsHitTesting(false)
        }
        .overlay {
            RoundedRectangle(cornerRadius: Theme.deckCorner, style: .continuous)
                .strokeBorder(Theme.rule, lineWidth: 1)
        }
        .overlay {
            RoundedRectangle(cornerRadius: Theme.deckCorner - 9, style: .continuous)
                .strokeBorder(accent.opacity(0.28), lineWidth: 1.5)
                .padding(9)
                .allowsHitTesting(false)
        }
        .shadow(color: .black.opacity(0.10), radius: 14, y: 6)
    }

    private var frameDot: some View {
        Circle()
            .fill(accent.opacity(0.4))
            .frame(width: 4, height: 4)
    }
}

/// Animatable 3D flip that swaps faces at the 90° midpoint. Conforming the
/// view itself to Animatable means SwiftUI interpolates `angle` every frame,
/// so the swap always happens while the card is edge-on.
// @preconcurrency: Animatable's requirement is nonisolated but SwiftUI only
// ever drives animatableData on the main thread, where this view lives.
private struct FlipRotation<Front: View, Back: View>: View, @preconcurrency Animatable {
    var angle: Double
    @ViewBuilder let front: () -> Front
    @ViewBuilder let back: () -> Back

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    var body: some View {
        ZStack {
            if angle < 90 {
                front()
            } else {
                // Pre-mirrored so it reads correctly once the container hits 180°.
                back()
                    .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
            }
        }
        .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.35)
    }
}
