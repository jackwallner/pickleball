import SwiftUI

/// Three screens: what the court is, where you are as a player, and which
/// half you play. Both answers change what the court generates.
struct OnboardingView: View {
    @EnvironmentObject private var profile: PlayerProfile

    private enum Step: Int, CaseIterable { case court, level, half }

    @State private var step: Step = .court
    @State private var level: ExperienceLevel?
    @State private var half: CourtHalf?
    @Environment(\.horizontalSizeClass) private var sizeClass

    /// A fixed, legal example: one opponent at the line, one still short, and
    /// a ball sitting up. The answer is to drive at the one who isn't set.
    private static let example = RallyPosition(
        id: "onboarding", phase: .thirdShot,
        you: CourtPoint(x: 6.5, y: 3.5),
        partner: CourtPoint(x: 14, y: 4),
        opponentLeft: CourtPoint(x: 6, y: 29.6),
        opponentRight: CourtPoint(x: 14.5, y: 34.5),
        contact: CourtPoint(x: 7, y: 6.2),
        ballHeight: .aboveNet,
        yourScore: 4, theirScore: 6, isServingTeam: true
    )

    private static let exampleOptions: [Shot] = [
        Shot(.drop, .crossCourtKitchen),
        Shot(.drive, .atFeet),
        Shot(.lob, .deepCrossCourt),
        Shot(.reset, .straightKitchen),
    ]

    var body: some View {
        VStack(spacing: 0) {
            progressDots
                .padding(.top, 12)

            // At the largest text sizes a step is taller than the screen;
            // then it scrolls and Continue stays pinned below it.
            ViewThatFits(in: .vertical) {
                stepContent
                ScrollView { stepContent }
                    .scrollBounceBehavior(.basedOnSize)
            }
            .id(step)
            .frame(maxWidth: Theme.readableContentWidth)
            .frame(maxHeight: .infinity)
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))

            Button(action: next) {
                Text(step == .half ? "Take me to the court" : "Continue")
                    .primaryCTA(color: canContinue ? Theme.court : Theme.card)
            }
            .buttonStyle(PressableCTAStyle())
            .disabled(!canContinue)
            .accessibilityIdentifier("onboarding-continue")
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
            .frame(maxWidth: Theme.readableContentWidth)
        }
        .frame(maxWidth: .infinity)
        .background(Theme.background.ignoresSafeArea())
        .animation(.spring(response: 0.4, dampingFraction: 0.9), value: step)
    }

    // MARK: - Steps

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .court: courtStep
        case .level: levelStep
        case .half: halfStep
        }
    }

    private var courtStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            CourtPOVView(
                position: Self.example,
                options: Self.exampleOptions,
                aimPoints: ShotAiming.aimPoints(for: Self.exampleOptions, in: Self.example),
                phase: .deciding,
                onPick: nil,
                chrome: .embedded
            )
            .frame(height: sizeClass == .regular ? 600 : 380)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 10) {
                Text("See the court. Call the shot.")
                    .font(Theme.display(34))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Every ball is a real rally position from where you stand. Read the ball's height against the net and where their feet are, then pick where it goes.")
                    .font(.body)
                    .foregroundStyle(Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
    }

    private var levelStep: some View {
        question(
            "Where's your game right now?",
            detail: "Your first focus points start where rallies at your level are usually lost."
        ) {
            ForEach(ExperienceLevel.allCases) { option in
                choice(option.title, detail: option.detail, selected: level == option,
                       id: "level-\(option.rawValue)") { level = option }
            }
        }
    }

    private var halfStep: some View {
        question(
            "Which side do you play?",
            detail: "Positions put you on that half, so the angles are the ones you see on court."
        ) {
            ForEach(CourtHalf.allCases) { option in
                choice(option.title, detail: option.detail, selected: half == option,
                       id: "half-\(option.rawValue)") { half = option }
            }
        }
    }

    // MARK: - Pieces

    private func question<Content: View>(
        _ title: String, detail: String, @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(Theme.display(32))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(detail)
                .font(.callout)
                .foregroundStyle(Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 8)
            content()
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.top, 36)
    }

    private func choice(
        _ title: String, detail: String, selected: Bool, id: String, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSecondary)
                }
                Spacer(minLength: 0)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(selected ? Theme.Surface.ball : Theme.inkTertiary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(selected ? Theme.court.opacity(0.35) : Theme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(selected ? Theme.courtLight : Theme.rule, lineWidth: 1)
            )
        }
        .buttonStyle(PressableCTAStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier(id)
    }

    private var progressDots: some View {
        HStack(spacing: 6) {
            ForEach(Step.allCases, id: \.self) { item in
                Capsule()
                    .fill(item.rawValue <= step.rawValue ? Theme.courtLight : Theme.rule)
                    .frame(width: item == step ? 22 : 8, height: 8)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(step.rawValue + 1) of \(Step.allCases.count)")
    }

    private var canContinue: Bool {
        switch step {
        case .court: return true
        case .level: return level != nil
        case .half: return half != nil
        }
    }

    private func next() {
        switch step {
        case .court:
            step = .level
        case .level:
            step = .half
        case .half:
            if let level { profile.level = level }
            if let half { profile.half = half }
            profile.markSetupComplete()
        }
    }
}
