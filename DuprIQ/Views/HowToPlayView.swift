import SwiftUI

/// The quick start: a short primer on how the licensing exam works, for
/// brand-new players. Runs inside onboarding (pass `onDone`, and `onSkip` for
/// the escape hatch) and re-opens from Home and Settings (dismisses itself).
///
/// Navigation is both swipe and button: drag the card left/right to page, and
/// Back sits NEXT to Continue where the thumb already is. (A back chevron in
/// the top-left corner is a mile from the thumb on the same screen where the
/// forward action is a full-width button at the bottom.)
struct HowToPlayView: View {
    var onDone: (() -> Void)?
    var onSkip: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @AppStorage("duprIQ.skillLevel") private var skillLevel = ""
    @AppStorage("duprIQ.recommendedCourtHint") private var recommendedCourtHint = ""
    /// Read to the end once: Home stops showing the primer card, and the
    /// primer becomes a Settings row like any other reference.
    @AppStorage("duprIQ.hasReadPrimer") private var hasReadPrimer = false
    @State private var index = 0
    @State private var goingForward = true
    @State private var shineTrigger = 0
    @State private var confettiTrigger = 0
    @State private var drag: CGFloat = 0

    private let pages = HowToPlayContent.pages
    private var page: HowToPlayPage { pages[index] }
    private var isLast: Bool { index == pages.count - 1 }
    private var isFirst: Bool { index == 0 }
    private var recommendedCourt: Court { HowToPlayContent.recommendedCourt(forSkillLevel: skillLevel) }

    var body: some View {
        VStack(spacing: 18) {
            progressDots
            Spacer(minLength: 0)
            pageCard
                .id(page.id)
                .offset(x: drag)
                .rotationEffect(.degrees(Double(drag / 40)), anchor: .bottom)
                .transition(goingForward
                    ? .asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    )
                    : .asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    )
                )
                .gesture(pageSwipe)
            Spacer(minLength: 0)
            footer
        }
        .padding()
        .frame(maxWidth: Theme.readableContentWidth)
        .frame(maxWidth: .infinity)
        .background(Theme.background)
        .tabBarClearance()
        .overlay { ConfettiBurst(trigger: confettiTrigger, origin: .init(x: 0.5, y: 0.35)) }
        .navigationTitle("How a Rally Works")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { fireShine() }
    }

    /// Swipe left for the next page, right for the previous one. The card
    /// tracks the finger and rubber-bands at both ends of the primer.
    private var pageSwipe: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                let atEdge = (value.translation.width > 0 && isFirst) || (value.translation.width < 0 && isLast)
                drag = atEdge ? value.translation.width * 0.25 : value.translation.width
            }
            .onEnded { value in
                let travel = value.translation.width
                let flung = abs(travel) > 60 || abs(value.predictedEndTranslation.width) > 160
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { drag = 0 }
                guard flung else { return }
                if travel < 0, !isLast {
                    advance()
                } else if travel > 0, !isFirst {
                    goBack()
                }
            }
    }

    private var progressDots: some View {
        HStack(spacing: 6) {
            ForEach(pages.indices, id: \.self) { dot in
                Capsule()
                    .fill(dot == index ? Theme.court : Theme.court.opacity(0.22))
                    .frame(width: dot == index ? 20 : 7, height: 7)
                    .animation(.snappy(duration: 0.22), value: index)
            }
        }
        .padding(.top, 6)
    }

    /// Back rides beside Continue, so paging in either direction is one thumb,
    /// one place. Skip only exists during onboarding, where it's a real exit.
    private var footer: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    goBack()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.headline)
                        .foregroundStyle(isFirst ? Theme.inkTertiary : Theme.court)
                        .frame(width: 56, height: 56)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(Theme.rule, lineWidth: 1)
                        )
                }
                .disabled(isFirst)
                .opacity(isFirst ? 0.45 : 1)
                .accessibilityLabel("Previous page")
                Button {
                    advance()
                } label: {
                    Text(isLast ? "Take your seat" : "Continue").primaryCTA()
                }
            }
            if let onSkip {
                Button {
                    recommendedCourtHint = recommendedCourt.id
                    onSkip()
                } label: {
                    Text("Skip for now")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.inkSecondary)
                }
            }
        }
    }

    private var pageCard: some View {
        VStack(spacing: 16) {
            Image(systemName: page.icon)
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(Theme.court)
                .frame(width: 76, height: 76)
                .background(Theme.court.opacity(0.12), in: Circle())
            Text(page.title)
                .font(Theme.display(27))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
            if !page.givens.isEmpty {
                GivensView(givens: page.givens, scale: 1.1)
            }
            Text(page.body)
                .font(.body)
                .foregroundStyle(Theme.inkSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let tip = page.tip {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(Theme.gold)
                    Text(tip)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.gold.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
            }
            if isLast {
                recommendationCard
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .themedCard(corner: 22)
        .shine(trigger: shineTrigger, corner: 22)
    }

    /// The primer's real next action: a tappable card recommending a court
    /// based on the onboarding skill level. Tapping it drives the same
    /// `advance()` as the primary button below (dismiss standalone / finish
    /// onboarding), and both routes set the one-shot hint `HomeView` consumes
    /// to highlight that court.
    private var recommendationCard: some View {
        Button {
            advance()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: recommendedCourt.icon)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(recommendedCourt.accent)
                    .frame(width: 40, height: 40)
                    .background(recommendedCourt.accent.opacity(0.14), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("Recommended: \(recommendedCourt.name)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                    Text(recommendedCourt.tagline)
                        .font(.caption)
                        .foregroundStyle(Theme.inkSecondary)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.inkTertiary)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(recommendedCourt.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(recommendedCourt.accent.opacity(0.35), lineWidth: 1.2)
            )
        }
        .buttonStyle(.plain)
    }

    private func goBack() {
        guard !isFirst else { return }
        Haptics.impact(.soft, intensity: 0.5)
        goingForward = false
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            index -= 1
        }
        fireShine()
    }

    private func advance() {
        if isLast {
            Haptics.success()
            hasReadPrimer = true
            recommendedCourtHint = recommendedCourt.id
            if let onDone {
                onDone()
            } else {
                dismiss()
            }
            return
        }
        Haptics.impact(.soft, intensity: 0.6)
        goingForward = true
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            index += 1
        }
        if index == pages.count - 1 {
            confettiTrigger += 1
        }
        fireShine()
    }

    private func fireShine() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            shineTrigger += 1
        }
    }
}
