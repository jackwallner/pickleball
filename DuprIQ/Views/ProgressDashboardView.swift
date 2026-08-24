import SwiftUI

struct ProgressDashboardView: View {
    @EnvironmentObject private var progress: ProgressStore

    var body: some View {
        NavigationStack {
            List {
                Section("Overall") {
                    LabeledContent("Day streak", value: "\(progress.streak)")
                    LabeledContent("Balls answered", value: "\(progress.totalAnswered)")
                }

                Section {
                    ForEach(RallyPhase.allCases) { phase in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(phase.title)
                                Text("\(progress.attemptCount(for: phase)) balls")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if let accuracy = progress.accuracy(for: phase) {
                                Text(accuracy.formatted(.percent.precision(.fractionLength(0))))
                                    .font(.body.monospacedDigit().weight(.semibold))
                                    .foregroundStyle(color(for: accuracy))
                            } else {
                                Text("-").foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("By phase")
                } footer: {
                    Text("Accuracy needs five balls in a phase before it means anything.")
                }
            }
            .navigationTitle("Progress")
        }
    }

    private func color(for accuracy: Double) -> Color {
        switch accuracy {
        case 0.8...: return .green
        case 0.6..<0.8: return .orange
        default: return .red
        }
    }
}
