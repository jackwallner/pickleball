import SwiftUI
import StoreKit

struct DrillCompleteView: View {
    let drill: Drill
    let score: Int?
    let total: Int
    var recordsCompletion = true
    /// Supplied when there is no navigation stack to pop (the onboarding
    /// tour's cover); otherwise Done just dismisses.
    var onDone: (() -> Void)?

    @EnvironmentObject private var progress: ProgressStore
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var reviews: ReviewPromptTracker
    @State private var showReviewPrompt = false
    @State private var recorded = false
    @State private var celebrate = false
    @State private var confettiTrigger = 0

    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Theme.court.opacity(0.12))
                    .frame(width: 132, height: 132)
                    .scaleEffect(celebrate ? 1 : 0.6)
                if let score {
                    VStack(spacing: 2) {
                        Text("\(score)/\(total)")
                            .font(Theme.display(34))
                            .foregroundStyle(Theme.court)
                            .monospacedDigit()
                        Text("right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.inkSecondary)
                    }
                } else {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 58))
                        .foregroundStyle(Theme.court)
                }
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.6), value: celebrate)
            VStack(spacing: 8) {
                Text(headline)
                    .font(Theme.display(30))
                    .foregroundStyle(Theme.ink)
                Text(subheadline)
                    .font(.body)
                    .foregroundStyle(Theme.inkSecondary)
                    .multilineTextAlignment(.center)
            }
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(Theme.ball)
                Text("\(progress.streakCount)-day streak")
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .themedCard(corner: 22)
            Spacer()
            Button {
                if let onDone { onDone() } else { dismiss() }
            } label: {
                Text("Done").primaryCTA()
            }
        }
        .padding()
        .background(Theme.background)
        .tabBarClearance()
        .overlay { ConfettiBurst(trigger: confettiTrigger, origin: .init(x: 0.5, y: 0.3), particleCount: 44) }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            celebrate = true
            confettiTrigger += 1
            guard !recorded else { return }
            recorded = true
            Haptics.success()
            SoundPlayer.play(.complete)
            if recordsCompletion {
                progress.recordSession(drillID: drill.id)
            }
            recordPositiveMoment()
        }
        .sheet(isPresented: $showReviewPrompt) {
            EnjoymentGateSheet()
        }
    }

    /// A finished drill is the positive moment the funnel waits for. Let the
    /// celebration land first: a sheet that lands on top of the confetti reads
    /// as an interruption, not a thank-you.
    private func recordPositiveMoment() {
        reviews.recordSessionFinished()
        guard reviews.shouldShowEnjoymentGate else { return }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            showReviewPrompt = true
        }
    }

    /// Plain language. "Deck cleared" and "Perfect round" are card-game
    /// vocabulary inherited from the app this shell was ported from, and a
    /// player reading them on a pickleball court can tell.
    private var headline: String {
        guard let score else { return "Session complete" }
        let fraction = Double(score) / Double(max(total, 1))
        if fraction >= 1 { return "All correct" }
        if fraction >= 0.7 { return "Good progress" }
        return "Review the misses"
    }

    private var subheadline: String {
        if score == nil {
            return ShellCopy.DrillComplete.flashcardsSubhead
        }
        return ShellCopy.DrillComplete.scoredSubhead
    }
}
