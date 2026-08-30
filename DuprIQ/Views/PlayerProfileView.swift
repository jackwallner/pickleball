import SwiftUI

/// The profile screen: how the player describes their game, which courts they
/// want first, and an optional next-match date.
///
/// Everything here changes something the app actually does. The level orders
/// the primer's recommendation, the focus areas order the courts on Home, and
/// the match date turns on the countdown and raises the daily target. A
/// question whose answer changed nothing would not be worth asking.
struct PlayerProfileView: View {
    @EnvironmentObject private var profile: PlayerProfile
    @Environment(\.dismiss) private var dismiss
    @AppStorage("duprIQ.skillLevel") private var skillLevel = ""

    @State private var hasMatchDate = false

    var body: some View {
        Form {
            Section {
                ForEach(ExperienceLevel.allCases) { level in
                    Button {
                        profile.selectLevel(level)
                        skillLevel = level.rawValue
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: level.icon)
                                .foregroundStyle(Theme.court)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(level.title)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(Theme.ink)
                                Text(level.detail)
                                    .font(.caption)
                                    .foregroundStyle(Theme.inkSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 4)
                            if profile.level == level && profile.hasSelectedLevel {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Theme.court)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("Where's your game?")
            } footer: {
                if profile.hasSelectedLevel {
                    Text(profile.level.emphasis)
                }
            }

            Section {
                ForEach(DrillLibrary.courts) { court in
                    Button {
                        if profile.focusAreas.contains(court.id) {
                            profile.focusAreas.remove(court.id)
                        } else {
                            profile.focusAreas.insert(court.id)
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: court.icon)
                                .foregroundStyle(Theme.ball)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(court.name)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(Theme.ink)
                                Text(court.tagline)
                                    .font(.caption)
                                    .foregroundStyle(Theme.inkSecondary)
                            }
                            Spacer(minLength: 4)
                            if profile.focusAreas.contains(court.id) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Theme.ball)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("What do you want first?")
            } footer: {
                // Worth being explicit: a player who reads this as a filter
                // will not tick anything, because they do not want the rest
                // taken away.
                Text("This orders the courts on Home. Nothing gets hidden.")
            }

            Section {
                Toggle("I have a match coming up", isOn: $hasMatchDate)
                if hasMatchDate {
                    DatePicker(
                        "Match day",
                        selection: Binding(
                            get: { profile.matchDate ?? Date().addingTimeInterval(7 * 86_400) },
                            set: { profile.matchDate = $0 }
                        ),
                        in: Date()...,
                        displayedComponents: .date
                    )
                }
                Stepper(
                    "Daily target: \(profile.dailyGoal) balls",
                    value: $profile.dailyGoal,
                    in: 5...100,
                    step: 5
                )
            } header: {
                Text("Practice target")
            } footer: {
                if profile.daysUntilMatch != nil {
                    Text("With a match booked the app suggests \(profile.suggestedDailyBalls) balls a day.")
                }
            }
        }
        .navigationTitle("Your game")
        .navigationBarTitleDisplayMode(.inline)
        .tabBarClearance()
        .onAppear {
            hasMatchDate = profile.matchDate != nil
            if skillLevel.isEmpty, profile.hasSelectedLevel {
                skillLevel = profile.level.rawValue
            }
        }
        .onChange(of: hasMatchDate) { _, enabled in
            if !enabled {
                profile.matchDate = nil
            } else if profile.matchDate == nil {
                profile.matchDate = Date().addingTimeInterval(7 * 86_400)
            }
        }
        .onDisappear { profile.markSetupComplete() }
    }
}
