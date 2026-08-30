import SwiftUI

/// What a session shows when it has no questions to run.
///
/// Every runner used to send `items.isEmpty` straight to `DrillCompleteView`,
/// which meant a stale review queue, a filtered-out locked item, or a deep link
/// that outlived its items rendered as a celebration for a session of zero
/// questions. That is a dead end wearing a confetti hat: it records a completed
/// session, fires the review-prompt funnel, and tells the reader nothing about
/// what to do next. An empty session is a state, and it says so.
struct SessionEmptyView: View {
    let title: String
    let message: String
    /// Supplied when there is no navigation stack to pop (a cover, the tour).
    var onDone: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(Theme.inkTertiary)
                .frame(width: 108, height: 108)
                .background(Theme.well, in: Circle())
            VStack(spacing: 8) {
                Text(title)
                    .font(Theme.display(26))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.body)
                    .foregroundStyle(Theme.inkSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Button {
                if let onDone { onDone() } else { dismiss() }
            } label: {
                Text("Back").primaryCTA()
            }
        }
        .padding()
        .frame(maxWidth: Theme.readableContentWidth)
        .frame(maxWidth: .infinity)
        .background(Theme.background)
        .tabBarClearance()
        .navigationBarTitleDisplayMode(.inline)
    }
}
