import StoreKit
import SwiftUI

/// The review funnel's gate. Only a Yes ever reaches Apple's sheet.
struct EnjoymentGateSheet: View {
    @EnvironmentObject private var reviews: ReviewPromptTracker
    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("Enjoying DUPR IQ?")
                .font(.title.bold())
            Text("A few sessions in. Is it helping your shot selection?")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
            Button("Yes, it's helping") {
                reviews.markPrompted()
                dismiss()
                requestReview()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Button("Not really") {
                reviews.markPrompted()
                dismiss()
            }
            .font(.footnote)
        }
        .padding()
        .presentationDetents([.medium])
    }
}
