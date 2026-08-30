import SwiftUI

/// First run: what the app is, where the player's game is, and what it will do
/// with that answer.
///
/// Three pages, not eight. The shell this was ported from asked a licence
/// track, a jurisdiction, a code-book edition and an exam date, because all
/// four changed what a candidate should study. Pickleball has one axis worth
/// asking about, and padding the flow to feel thorough would just be four
/// screens between someone and the first drill.
struct OnboardingView: View {
    @EnvironmentObject private var profile: PlayerProfile
    @EnvironmentObject private var progress: ProgressStore
    @AppStorage("duprIQ.skillLevel") private var skillLevel = ""

    @State private var page = 0
    @State private var showLevelRequired = false

    var onFinish: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                welcomePage.tag(0)
                levelPage.tag(1)
                readyPage.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            if showLevelRequired && page == 1 && !profile.hasSelectedLevel {
                Text("Choose the level that fits you best to continue.")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.court)
                    .accessibilityIdentifier("onboarding-level-required")
            }

            Button {
                advance()
            } label: {
                Text(page == 2 ? "Start practising" : "Continue")
                    .primaryCTA()
            }
            .buttonStyle(PressableCTAStyle())
            .accessibilityIdentifier("onboarding-continue")
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(Theme.background)
    }

    // MARK: - Pages

    private var welcomePage: some View {
        page(
            icon: "sportscourt.fill",
            title: "Shot selection, drilled",
            body: "A court, four players' feet, and four shots to choose from. Every answer names the coaching principle it came from, so you leave knowing why rather than just what."
        ) {
            VStack(alignment: .leading, spacing: 10) {
                benefit("infinity", ShellCopy.Onboarding.generatorBenefit)
                benefit("quote.bubble.fill", ShellCopy.Onboarding.principleBenefit)
                benefit("lock.open.fill", ShellCopy.Onboarding.freeCourtsBenefit)
            }
        }
    }

    private var levelPage: some View {
        page(
            icon: "figure.pickleball",
            title: "Where's your game?",
            body: "This orders what the app shows you first. You can change it any time in Settings."
        ) {
            VStack(spacing: 8) {
                ForEach(ExperienceLevel.allCases) { level in
                    Button {
                        profile.selectLevel(level)
                        skillLevel = level.rawValue
                        showLevelRequired = false
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: level.icon)
                                .foregroundStyle(profile.level == level && profile.hasSelectedLevel ? .white : Theme.court)
                                .frame(width: 26)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(level.title)
                                    .font(.subheadline.weight(.semibold))
                                Text(level.detail)
                                    .font(.caption)
                                    .opacity(0.8)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                        }
                        .multilineTextAlignment(.leading)
                        .foregroundStyle(profile.level == level && profile.hasSelectedLevel ? Color.white : Theme.ink)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(profile.level == level && profile.hasSelectedLevel ? Theme.court : Theme.card)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Theme.rule, lineWidth: profile.level == level && profile.hasSelectedLevel ? 0 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("onboarding-level-\(level.rawValue)")
                }
            }
        }
    }

    private var readyPage: some View {
        page(
            icon: "checkmark.seal.fill",
            title: profile.hasSelectedLevel ? profile.level.title : "You're set",
            body: profile.hasSelectedLevel ? profile.level.emphasis : "Two courts are free forever, and the free tier grades fifteen balls a day."
        ) {
            VStack(alignment: .leading, spacing: 10) {
                benefit("calendar", "Fifteen graded balls a day, free")
                benefit("chart.bar.fill", "Accuracy by phase, so you know where to work")
                benefit("bolt.fill", "Pro adds unlimited balls, history, and your missed principles")
                Text(ShellCopy.Legal.duprDisclaimer)
                    .font(.caption2)
                    .foregroundStyle(Theme.inkTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)
            }
        }
    }

    // MARK: - Scaffolding

    private func advance() {
        if page == 1 && !profile.hasSelectedLevel {
            Haptics.impact(.light, intensity: 0.8)
            withAnimation { showLevelRequired = true }
            return
        }
        if page < 2 {
            withAnimation { page += 1 }
        } else {
            finish()
        }
    }

    @ViewBuilder
    private func page<Content: View>(
        icon: String,
        title: String,
        body: String,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        // Centering, not top-aligned. A plain ScrollView pinned the welcome
        // page's four short lines to the top and left the bottom 40% of the
        // screen empty, which is the first thing a new player ever sees.
        CenteringScrollView {
            VStack(spacing: 18) {
                Image(systemName: icon)
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(Theme.court)
                    .padding(.top, 8)
                Text(title)
                    .font(Theme.display(28))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                Text(body)
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                content()
                    .padding(.top, 4)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 60)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
    }

    private func benefit(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(Theme.court)
                .frame(width: 22)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    private func finish() {
        progress.hasOnboarded = true
        profile.markSetupComplete()
        // A player who has only ever run this version must not be shown notes
        // about what changed in it.
        WhatsNew.markCurrentAsBaseline()
        onFinish()
    }
}
