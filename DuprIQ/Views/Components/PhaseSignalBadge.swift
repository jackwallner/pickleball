import SwiftUI

/// Renders what a phase's record actually supports: nothing, a sample count, or
/// a real percentage. A big red 0% after one ball is a lie the eye believes
/// before it reads the footnote explaining that it is not one.
struct PhaseSignalBadge: View {
    let signal: PhaseSignal

    var body: some View {
        switch signal {
        case .untried:
            Text("New")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityLabel("Not practised yet")
        case .building(let answered, let needed):
            Text("\(answered) of \(needed)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .accessibilityLabel("\(answered) of \(needed) balls toward an accuracy")
        case .measured(let accuracy):
            Text(accuracy.formatted(.percent.precision(.fractionLength(0))))
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .foregroundStyle(Self.color(for: accuracy))
                .accessibilityLabel("\(Int((accuracy * 100).rounded())) percent accurate")
        }
    }

    static func color(for accuracy: Double) -> Color {
        switch accuracy {
        case 0.8...: return .green
        case 0.6..<0.8: return .orange
        default: return .red
        }
    }
}
