import SwiftUI

/// One court, its drills. Free drills open; DUPR IQ Pro extra sets show the lock and
/// route to the paywall. A locked court (the worked calculations) locks every row.
struct CourtView: View {
    let court: Court

    @EnvironmentObject private var progress: ProgressStore
    @EnvironmentObject private var subscriptions: SubscriptionService
    @State private var showPaywall = false

    private var courtLocked: Bool { !court.isFree && !subscriptions.isPro }
    private var lockedCount: Int {
        court.drills.filter { court.isLocked($0, isMember: subscriptions.isPro) }.count
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                header
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 320), spacing: 14)],
                    spacing: 14
                ) {
                    ForEach(court.drills) { drill in
                        drillRow(drill)
                    }
                }
                if lockedCount > 0 {
                    upsell
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
            .frame(maxWidth: Theme.wideContentWidth)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.background)
        .navigationTitle(court.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPaywall) { PaywallView(source: "dupriq_court_sheet") }
    }

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: court.icon)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(court.accent)
                .frame(width: 66, height: 66)
                .background(court.accent.opacity(0.12), in: Circle())
            Text(court.name)
                .font(Theme.display(28))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
            Text(court.tagline)
                .font(.subheadline)
                .foregroundStyle(Theme.inkSecondary)
                .multilineTextAlignment(.center)
            if courtLocked {
                // A locked court still shows its drills below, so this is a
                // preview, not a dead end. Say so, or the lock reads as a wall.
                Text("Look around. Every drill here opens with \(Membership.name).")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.gold)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        .padding(.bottom, 2)
    }

    @ViewBuilder
    private func drillRow(_ drill: Drill) -> some View {
        let locked = court.isLocked(drill, isMember: subscriptions.isPro)
        if locked {
            Button {
                showPaywall = true
            } label: {
                drillRowBody(drill, locked: true)
            }
            .buttonStyle(PressableCardStyle())
        } else {
            NavigationLink {
                destination(drill)
            } label: {
                drillRowBody(drill, locked: false)
            }
            .buttonStyle(PressableCardStyle())
        }
    }

    private func drillRowBody(_ drill: Drill, locked: Bool) -> some View {
        let done = progress.completions(for: drill.id) > 0
        return HStack(spacing: 14) {
            Image(systemName: drill.kind.symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(locked ? court.accent.opacity(0.55) : court.accent)
                .frame(width: 42, height: 42)
                .background(court.accent.opacity(locked ? 0.08 : 0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(drill.title)
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.leading)
                    if locked {
                        PlusBadge()
                    }
                }
                Text(drill.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSecondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                Text("\(drill.kind.itemCount) \(drill.kind.unitName)")
                    .font(.caption)
                    .foregroundStyle(Theme.inkTertiary)
            }
            Spacer(minLength: 4)
            if locked {
                Image(systemName: "lock.fill")
                    .font(.footnote)
                    .foregroundStyle(Theme.gold)
            } else if done {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(court.accent)
            } else {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.inkTertiary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .themedCard(corner: 16)
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    /// Says exactly what the money buys IN THIS ROOM, which is the whole point
    /// of the extra sets: same drills, more reps.
    private var upsell: some View {
        Button {
            showPaywall = true
        } label: {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(Theme.gold)
                    Text("\(lockedCount) more \(lockedCount == 1 ? "drill" : "drills") in this court")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                    Spacer(minLength: 0)
                }
                Text("\(Membership.name) unlocks the extra sets here and in every other court, the worked reads, the Daily Drill, Match Warm-Up, and unlimited generated practice. Everything you already have stays free.")
                    .font(.caption)
                    .foregroundStyle(Theme.inkSecondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
            .background(Theme.gold.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Theme.gold.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(PressableCardStyle())
        .padding(.top, 4)
    }

    @ViewBuilder
    private func destination(_ drill: Drill) -> some View {
        switch drill.kind {
        case .flashcards(let cards):
            FlashcardDrillView(drill: drill, cards: cards, accent: court.accent)
        case .quiz(let questions):
            QuizDrillView(drill: drill, questions: questions)
        case .principleMatch(let questions):
            // Article match is a quiz whose choices happen to be articles, so
            // it runs through the same view rather than duplicating one.
            QuizDrillView(drill: drill, questions: questions.map(\.asQuizQuestion))
        case .worked(let scenarios):
            WorkedDrillView(drill: drill, scenarios: scenarios)
        }
    }
}
