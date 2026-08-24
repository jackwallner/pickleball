import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var subscriptions: SubscriptionService
    @EnvironmentObject private var progress: ProgressStore
    @EnvironmentObject private var limiter: PracticeLimiter
    @EnvironmentObject private var reviews: ReviewPromptTracker

    @State private var showPaywall = false
    @State private var showEnjoymentGate = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        DrillSessionView()
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Today's rally").font(.headline)
                            Text("10 balls across every phase of the point")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    .accessibilityIdentifier("mixed-rally")

                    if let weakest = progress.weakestPhase {
                        NavigationLink {
                            DrillSessionView(phase: weakest)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Label("Work your weakest phase", systemImage: "target")
                                    .font(.headline)
                                Text(weakest.title)
                                    .font(.footnote).foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                        .accessibilityIdentifier("weakest-phase")
                    }
                } header: {
                    Text("Practice")
                } footer: {
                    if !subscriptions.isPro {
                        Text("\(limiter.remaining(isPro: false)) of \(PracticeLimiter.freeDailyBalls) free balls left today.")
                    }
                }

                Section("Rooms") {
                    ForEach(RallyPhase.allCases) { phase in
                        NavigationLink {
                            DrillSessionView(phase: phase)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(phase.title)
                                    Text(phase.subtitle)
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if let accuracy = progress.accuracy(for: phase) {
                                    Text(accuracy.formatted(.percent.precision(.fractionLength(0))))
                                        .font(.subheadline.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .accessibilityIdentifier("room-\(phase.rawValue)")
                    }
                }

                if !subscriptions.isPro {
                    Section {
                        Button {
                            showPaywall = true
                        } label: {
                            Label("Unlimited balls with Pro", systemImage: "infinity")
                        }
                        .accessibilityIdentifier("home-paywall")
                    }
                }
            }
            .navigationTitle(progress.streak > 0 ? "\(progress.streak) day streak" : "DUPR IQ")
            .contentMargins(.bottom, 28, for: .scrollContent)
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .sheet(isPresented: $showEnjoymentGate) { EnjoymentGateSheet() }
            .onAppear {
                if reviews.shouldShowEnjoymentGate { showEnjoymentGate = true }
            }
        }
    }
}
