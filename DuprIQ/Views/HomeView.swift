import SwiftUI

/// Home is the lobby: today's rally, the six phases, then the courts as doors.
/// The authored drills live one level down in `CourtView`.
///
/// The generated practice sits at the TOP rather than behind a tile, because
/// the generator is the product. The shell this was ported from buried its
/// generator under a "Training" tile because its authored library was the
/// headline; here the relationship is the other way round, and a lobby that
/// made someone tap twice to reach a fresh court would be describing a
/// different app.
///
/// Everything else earns its space or leaves: the stats ride beside the title
/// instead of eating a row, and the primer card disappears once it is read.
struct HomeView: View {
    @EnvironmentObject private var progress: ProgressStore
    @EnvironmentObject private var subscriptions: SubscriptionService
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var profile: PlayerProfile
    @EnvironmentObject private var limiter: PracticeLimiter
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject private var records = PracticeRecordStore.shared
    @StateObject private var minuteStore = DailyDrillStore.shared
    /// Untyped on purpose: this stack pushes two unrelated destinations, a
    /// generated `DrillRoute` and an authored `AppDestination`, and a typed
    /// path can only carry one of them.
    @State private var path = NavigationPath()
    @State private var showPaywall = false
    @State private var showSettings = false
    @State private var showWhatsNew = false
    @State private var pendingAfterUpgrade: AppDestination?
    @State private var highlightedCourtID: String?

    /// Where a generated-practice row goes. Routing through a value rather than
    /// a `NavigationLink` is what lets the free allowance be checked BEFORE a
    /// court is drawn: reading a position, choosing a shot and only then
    /// meeting a paywall is a bait-and-switch even when the limit is documented.
    struct DrillRoute: Hashable {
        let phase: RallyPhase?
    }
    @AppStorage("duprIQ.skillLevel") private var skillLevel = ""
    /// Set once the primer has been read all the way through. After that it
    /// lives in Settings only; a permanent "How a rally works" card on Home is a
    /// standing tax on the courts below it.
    @AppStorage("duprIQ.hasReadPrimer") private var hasReadPrimer = false
    /// One-shot hint set by `HowToPlayView`'s end-of-primer recommendation:
    /// the court id to highlight/scroll to the next time Home appears.
    @AppStorage("duprIQ.recommendedCourtHint") private var recommendedCourtHint = ""

    private var showsPrimerCard: Bool { skillLevel == "new" && !hasReadPrimer }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollViewReader { proxy in
                ScrollView {
                    homeContent
                    .padding(.bottom, 24)
                }
                // Clearance for the floating tab bar. 60pt was measured
                // against an older bar and left the last card sliced in half
                // behind the Practice/Progress/Settings pill.
                .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 96) }
                .onAppear {
                    consumeRecommendedCourtHint(proxy: proxy)
                    consumePendingDestination()
                    settings.updateMatchWarmUpScheduling(isPro: subscriptions.isPro)
                }
                .onChange(of: showSettings) { _, isShowing in
                    if !isShowing { consumeRecommendedCourtHint(proxy: proxy) }
                }
            }
            .background(Theme.background)
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationDestination(for: DrillRoute.self) { route in
                DrillSessionView(phase: route.phase)
            }
            .navigationDestination(for: AppDestination.self) { destination in
                switch destination {
                case .matchWarmUpSession:
                    QuickSessionView(matchWarmUp: matchWarmUpItems)
                }
            }
            .sheet(isPresented: $showPaywall) { PaywallView(source: "dupriq_home_sheet") }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showWhatsNew) {
                if let release = WhatsNew.currentRelease {
                    WhatsNewSheet(release: release) {
                        showWhatsNew = false
                        // The sheet cannot present the paywall while it is
                        // dismissing, so hand off on the next runloop.
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 350_000_000)
                            showPaywall = true
                        }
                    }
                }
            }
            .task { presentWhatsNewIfNeeded() }
            .onChange(of: router.pendingDestination) { _, _ in consumePendingDestination() }
            .onChange(of: subscriptions.isPro) { _, isMember in
                settings.updateMatchWarmUpScheduling(isPro: isMember)
                if isMember {
                    if let pendingAfterUpgrade {
                        self.pendingAfterUpgrade = nil
                        path = NavigationPath()
                        path.append(pendingAfterUpgrade)
                    } else {
                        consumePendingDestination()
                    }
                }
            }
            .onChange(of: showPaywall) { _, isShowing in
                if !isShowing, !subscriptions.isPro { pendingAfterUpgrade = nil }
            }
        }
        .tint(Theme.court)
    }

    @ViewBuilder
    private var homeContent: some View {
        if horizontalSizeClass == .regular {
            VStack(spacing: 18) {
                header
                HStack(alignment: .top, spacing: 20) {
                    todayColumn
                    courtsColumn
                }
                disclaimerFooter
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: Theme.wideContentWidth)
            .frame(maxWidth: .infinity)
        } else {
            VStack(spacing: 14) {
                header
                rallyCard
                phasesSection
                allowanceFooter
                todaySession
                if !profile.setupComplete {
                    playerTargetCard
                } else if profile.daysUntilMatch != nil {
                    matchCountdownCard
                }
                if showsPrimerCard { howToPlayCard }
                trainingSection
                courtsColumn
                if !subscriptions.isPro { upgradeCard }
                disclaimerFooter
            }
            .padding(.horizontal)
        }
    }


    // MARK: - Generated practice
    //
    // The part of the app that never runs out, and the part the free tier is
    // metered on. Authored courts are deliberately NOT metered: two of them are
    // free forever, and counting a finite library against a daily cap would
    // quietly take back what the free tier promised.

    private var rallyCard: some View {
        Button {
            start(phase: nil)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "figure.pickleball")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(Theme.court, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Play a point")
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                    Text("Rallies across every phase, at your pace")
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.inkTertiary)
            }
            .padding(14)
            .themedCard(corner: 18)
        }
        .buttonStyle(PressableCardStyle())
        .accessibilityIdentifier("mixed-rally")
    }

    /// The six phases, each showing only what its record actually supports.
    /// A big red 0% after one ball is a lie the eye believes before it reads
    /// the footnote explaining that it is not one, so an untried phase says
    /// "New" and a thin sample says how thin it is.
    private var phasesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("PHASES")
                    .font(.caption.weight(.heavy))
                    .kerning(1.4)
                    .foregroundStyle(Theme.inkSecondary)
                Spacer()
                if let recommendation = progress.recommendation {
                    Button {
                        start(phase: recommendation.phase)
                    } label: {
                        Label(
                            // Before there is enough evidence this is a
                            // suggestion, not a measurement. Calling an
                            // untouched phase someone's "weakest" is a claim
                            // the app has not earned.
                            recommendation.isMeasured ? "Work your weakest" : "Suggested next",
                            systemImage: recommendation.isMeasured ? "target" : "arrow.right.circle"
                        )
                        .font(.caption.weight(.semibold))
                    }
                    .accessibilityIdentifier("weakest-phase")
                }
            }
            .padding(.horizontal, 4)

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                spacing: 10
            ) {
                ForEach(RallyPhase.allCases) { phase in
                    Button {
                        start(phase: phase)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .top, spacing: 4) {
                                Image(systemName: phase.icon)
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(Theme.court)
                                Spacer(minLength: 0)
                                PhaseSignalBadge(signal: progress.signal(for: phase))
                            }
                            // Both lines reserve their space. A LazyVGrid
                            // row is as tall as its tallest cell, so a
                            // one-line subtitle next to a two-line one left
                            // half the tile empty.
                            Text(phase.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.ink)
                                .multilineTextAlignment(.leading)
                                .lineLimit(2, reservesSpace: true)
                            Text(phase.subtitle)
                                .font(.caption2)
                                .foregroundStyle(Theme.inkSecondary)
                                .multilineTextAlignment(.leading)
                                .lineLimit(2, reservesSpace: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding(12)
                        .themedCard(corner: 16)
                    }
                    .buttonStyle(PressableCardStyle())
                    .accessibilityIdentifier("court-\(phase.rawValue)")
                }
            }
        }
    }

    /// The allowance, stated before it runs out rather than at the moment it
    /// does.
    @ViewBuilder
    private var allowanceFooter: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !subscriptions.isPro {
                Text("\(limiter.remaining(isPro: false)) of \(PracticeLimiter.freeDailyBalls) free balls left today.")
            }
            if progress.streak > 0 {
                Text("\(progress.streak) day streak. A day counts at \(ProgressThreshold.ballsForPracticeDay) balls.")
            } else if progress.totalAnswered > 0 {
                Text("\(progress.ballsToPracticeDay) more balls today and the streak starts.")
            }
        }
        .font(.caption)
        .foregroundStyle(Theme.inkTertiary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }

    /// The free cap is checked here, before the court is drawn.
    private func start(phase: RallyPhase?) {
        limiter.rollOverIfNeeded()
        guard limiter.canPractice(isPro: subscriptions.isPro) else {
            showPaywall = true
            return
        }
        path.append(DrillRoute(phase: phase))
    }

    private var todayColumn: some View {
        VStack(spacing: 14) {
            rallyCard
            phasesSection
            allowanceFooter
            todaySession
            if !profile.setupComplete {
                playerTargetCard
            } else if profile.daysUntilMatch != nil {
                matchCountdownCard
            }
            if showsPrimerCard { howToPlayCard }
            trainingSection
            if !subscriptions.isPro { upgradeCard }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private var courtsColumn: some View {
        VStack(spacing: 14) {
            courtsHeading
            ForEach(orderedCourts) { court in
                courtCard(court)
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    @ViewBuilder
    private var todaySession: some View {
        if progress.quickSessionCompletedToday() {
            getStartedDoneCard
        } else {
            getStartedCard
        }
    }

    private var matchWarmUpItems: [QuickItem] {
        SessionBuilder.matchWarmUp(
            seen: progress.seenItems,
            missed: progress.missedItems,
            dueIDs: records.reviewQueue(),
            weakestCourtID: records.weakestCourt()?.id
        )
    }

    /// The review session: the authored questions the scheduler says are due,
    /// then a freshly generated problem for each mistake PATTERN still
    /// outstanding.
    ///
    /// The second half is what makes the promise honest for generated practice.
    /// A generated question is a one-off, so it can never come back as itself;
    /// what comes back is the trap. Replaying a remembered question would teach
    /// less than a new one that punishes the same error.
    private var fixMyMistakesItems: [QuickItem] {
        let due = SessionBuilder.reviewSession(
            ids: records.reviewQueue(),
            includePro: subscriptions.isPro
        )
        let patterns = records.outstandingMistakes()
        let targeted = EndlessPractice.targetedItems(
            for: patterns,
            count: min(patterns.count * 2, max(0, 12 - due.count))
        )
        return due + targeted
    }

    private func consumePendingDestination() {
        guard let destination = router.consumePendingDestination() else { return }
        guard subscriptions.isPro else {
            pendingAfterUpgrade = destination
            showPaywall = true
            return
        }
        path = NavigationPath()
        path.append(destination)
    }

    /// The post-update note, once. Deliberately deferred a beat so it lands on
    /// a drawn Home rather than racing the first frame.
    private func presentWhatsNewIfNeeded() {
        guard WhatsNew.shouldPresent(hasOnboarded: progress.hasOnboarded) else { return }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            showWhatsNew = true
        }
    }

    /// Consumes the one-shot recommendation hint: scrolls to and briefly
    /// highlights the recommended court's card, then clears the hint so it
    /// only ever fires once per recommendation.
    private func consumeRecommendedCourtHint(proxy: ScrollViewProxy) {
        guard !recommendedCourtHint.isEmpty else { return }
        let courtID = recommendedCourtHint
        recommendedCourtHint = ""
        guard DrillLibrary.courts.contains(where: { $0.id == courtID }) else { return }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 400_000_000)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                proxy.scrollTo(courtID, anchor: .center)
                highlightedCourtID = courtID
            }
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            withAnimation(.easeOut(duration: 0.4)) { highlightedCourtID = nil }
        }
    }

    // MARK: - Header (title left, stats right, one row total)

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("DUPR IQ")
                    .font(Theme.display(32))
                    .foregroundStyle(Theme.ink)
                Text("Shot selection, drilled")
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSecondary)
            }
            Spacer(minLength: 8)
            // The chips were already the honest summary of practice, so they
            // are also the door to the full breakdown rather than yet another
            // row competing with the courts.
            NavigationLink {
                ProgressDashboardView()
            } label: {
                HStack(spacing: 8) {
                    statChip(value: progress.streakCount, icon: "flame.fill", color: Theme.ball,
                             label: "\(progress.streakCount) day streak")
                    statChip(value: progress.totalAnswered, icon: "checkmark.seal.fill", color: Theme.court,
                             label: "\(progress.totalAnswered) balls graded")
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens your progress breakdown")
            .padding(.top, 4)
        }
        .padding(.top, 2)
    }

    private func statChip(value: Int, icon: String, color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text("\(value)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Theme.ink)
                .monospacedDigit()
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(color.opacity(0.12), in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
    }

    /// The one-tap way in: builds a short mixed session, no browsing needed.
    private var getStartedCard: some View {
        NavigationLink {
            QuickSessionView(items: SessionBuilder.quickSession(
                seen: progress.seenItems,
                missed: progress.missedItems,
                includePro: subscriptions.isPro
            ))
        } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Get Started")
                        .font(Theme.display(24))
                        .foregroundStyle(.white)
                    Text("A short mix of what you need next")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                }
                Spacer(minLength: 4)
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.white)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [Theme.court, Theme.court.opacity(0.82)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous)
            )
            .shadow(color: Theme.court.opacity(0.3), radius: 10, y: 5)
        }
        .buttonStyle(PressableCardStyle())
    }

    /// Today's Get Started is spent. Rather than hand back the same questions
    /// (a repeat teaches nothing), the card rests and points at the courts for
    /// more practice, and comes back fresh tomorrow.
    private var getStartedDoneCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 30))
                .foregroundStyle(Theme.court)
                .frame(width: 44, height: 44)
                .background(Theme.court.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text("Today's session is done")
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                Text("A fresh mix lands tomorrow. Keep going in any court below.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard()
    }

    /// Shown only until the primer has actually been read; after that it's a
    /// Settings row like every other reference material.
    private var howToPlayCard: some View {
        NavigationLink {
            HowToPlayView()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "book.fill")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.gold)
                    .frame(width: 38, height: 38)
                    .background(Theme.gold.opacity(0.13), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("How a rally works")
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                    Text("New here? Start with the five-minute primer")
                        .font(.caption)
                        .foregroundStyle(Theme.inkSecondary)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.inkTertiary)
            }
            .padding(12)
            .themedCard(corner: 16)
        }
        .buttonStyle(PressableCardStyle())
    }

    /// Focus picks from onboarding float to the top. Nothing is hidden: the
    /// question was "what do you want to hit hardest", not "what should we
    /// take away", so this is an ordering, not a filter.
    private var orderedCourts: [Court] {
        guard !profile.focusAreas.isEmpty else { return DrillLibrary.courts }
        let focused = DrillLibrary.courts.filter { profile.focusAreas.contains($0.id) }
        let rest = DrillLibrary.courts.filter { !profile.focusAreas.contains($0.id) }
        return focused + rest
    }

    /// The countdown, once there is a match to count to. It reads back the
    /// daily number the setup promised, so the match-date answer keeps paying
    /// off after onboarding instead of vanishing into UserDefaults.
    private var matchCountdownCard: some View {
        NavigationLink {
            PlayerProfileView()
        } label: {
            HStack(spacing: 12) {
                VStack(spacing: 0) {
                    Text("\(profile.daysUntilMatch ?? 0)")
                        .font(Theme.numeric(20, weight: .bold))
                        .foregroundStyle(Theme.court)
                    Text((profile.daysUntilMatch ?? 0) == 1 ? "day" : "days")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.inkTertiary)
                }
                .frame(width: 46, height: 46)
                .background(Theme.court.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.targetSummary)
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                    Text("\(profile.levelSummary). Target \(profile.suggestedDailyBalls) balls a day.")
                        .font(.caption)
                        .foregroundStyle(Theme.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.inkTertiary)
            }
            .padding(12)
            .themedCard(corner: 16)
        }
        .buttonStyle(PressableCardStyle())
    }

    private var playerTargetCard: some View {
        NavigationLink {
            PlayerProfileView()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "person.text.rectangle.fill")
                    .foregroundStyle(Theme.court)
                    .frame(width: 38, height: 38)
                    .background(Theme.court.opacity(0.12), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tell us about your game")
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                    Text("Pick a level and the courts you want first")
                        .font(.caption)
                        .foregroundStyle(Theme.inkSecondary)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.inkTertiary)
            }
            .padding(12)
            .themedCard(corner: 16)
        }
        .buttonStyle(PressableCardStyle())
    }

    // MARK: - Training modes

    /// The cross-cutting practice modes. They sit above the courts
    /// because they are what a returning player comes back FOR, but they ride
    /// in one scrolling row of compact tiles rather than three full-width
    /// cards: Home's job is still the courts, and everything else earns its
    /// space.
    private var trainingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("TRAINING")
                    .font(.caption.weight(.heavy))
                    .kerning(1.4)
                    .foregroundStyle(Theme.inkSecondary)
                Spacer()
            }
            .padding(.horizontal, 4)
            if horizontalSizeClass == .regular {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                    trainingTiles
                }
                .padding(.horizontal, 4)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        trainingTiles
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                }
            }
        }
    }

    @ViewBuilder
    private var trainingTiles: some View {
        // Not a `trainingTile`: those are Pro-locked, and generated practice is
        // the free tier's whole product. It is metered by the daily allowance
        // instead, which the lobby states above.
        NavigationLink {
            EndlessPickerView()
        } label: {
            trainingTileLabel(
                title: "Endless\nPractice",
                icon: "infinity",
                color: Theme.court,
                badge: subscriptions.isPro ? "Unlimited" : "\(limiter.remaining(isPro: false)) left",
                locked: false
            )
        }
        .accessibilityIdentifier("tile-endless")
        .buttonStyle(PressableCardStyle())
        trainingTile(
            title: "Daily\nDrill",
            icon: "calendar.badge.clock",
            color: Theme.ball,
            badge: minuteStore.result(for: Date()).map { "\($0.score)/\($0.total) today" } ?? "Daily",
            identifier: "tile-daily"
        ) {
            DailyDrillView()
        }
        trainingTile(
            title: "Match\nWarm-Up",
            icon: "person.2.fill",
            color: Theme.slate,
            badge: settings.matchWarmUpReminderEnabled ? settings.matchWarmUpDay.displayName : "Weekly",
            identifier: "tile-warmup"
        ) {
            QuickSessionView(matchWarmUp: matchWarmUpItems)
        }
        trainingTile(
            title: "Timed\nChallenge",
            icon: "timer",
            color: Theme.ball,
            badge: records.bestChallengeScore > 0 ? "Best \(records.bestChallengeScore)" : nil,
            identifier: "tile-timed"
        ) {
            PracticeRunView(mode: .timed)
        }
        // Only offered when there is something to fix. An empty review
        // session is a dead end dressed up as a feature.
        //
        // The due COUNT is hidden from free readers on purpose. The tile is
        // paywalled like every other training mode, and showing "4 due" on a
        // button that answers with a paywall is the worst possible moment to
        // ask for money: they just missed something and came here to fix it.
        // Locked, it advertises what the mode is instead of what they cannot
        // have.
        if records.fixableCount > 0 {
            trainingTile(
                title: "Fix My\nMistakes",
                icon: "arrow.trianglehead.counterclockwise",
                color: Theme.slate,
                badge: subscriptions.isPro ? "\(records.fixableCount) to fix" : "Unlock",
                identifier: "tile-fix"
            ) {
                PracticeRunView(mode: .review, items: fixMyMistakesItems)
            }
        }
    }

    /// A compact training tile. Locked for free players: tapping opens the
    /// paywall instead of the mode, and the tile says so before it is tapped.
    @ViewBuilder
    private func trainingTile<Destination: View>(
        title: String,
        icon: String,
        color: Color,
        badge: String?,
        // Stable handle for the capture and audit runs. The tiles carry
        // multi-line titles and a badge that changes with progress, so
        // addressing them by label meant a harness that broke whenever the copy
        // or the streak did.
        identifier: String,
        @ViewBuilder destination: @escaping () -> Destination
    ) -> some View {
        let locked = !subscriptions.isPro
        if locked {
            Button { showPaywall = true } label: {
                trainingTileLabel(title: title, icon: icon, color: color, badge: badge, locked: true)
            }
            .accessibilityIdentifier(identifier)
            .buttonStyle(PressableCardStyle())
            .accessibilityHint("Included with \(Membership.name)")
        } else {
            NavigationLink { destination() } label: {
                trainingTileLabel(title: title, icon: icon, color: color, badge: badge, locked: false)
            }
            .accessibilityIdentifier(identifier)
            .buttonStyle(PressableCardStyle())
        }
    }

    private func trainingTileLabel(title: String, icon: String, color: Color, badge: String?, locked: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(color)
                Spacer(minLength: 0)
                if locked {
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                        .foregroundStyle(Theme.gold)
                }
            }
            Spacer(minLength: 0)
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            if let badge {
                Text(badge)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(color)
            } else {
                Text(locked ? Membership.name : " ")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.gold)
            }
        }
        .padding(12)
        .frame(width: horizontalSizeClass == .regular ? nil : 128, height: 118, alignment: .leading)
        .frame(maxWidth: horizontalSizeClass == .regular ? .infinity : nil, alignment: .leading)
        .themedCard(corner: 16)
    }

    // MARK: - Courts

    private var courtsHeading: some View {
        HStack {
            Text("THE COURTS")
                .font(.caption.weight(.heavy))
                .kerning(1.4)
                .foregroundStyle(Theme.inkSecondary)
            Spacer()
        }
        .padding(.top, 6)
        .padding(.horizontal, 4)
    }

    /// Progress is a ring, not a sentence. "2 of 3 done · 2 free, 1 with DUPR IQ Pro"
    /// was three facts nobody asked for on a card whose job is to be a door.
    private func courtCard(_ court: Court) -> some View {
        let locked = !court.isFree && !subscriptions.isPro
        let highlighted = highlightedCourtID == court.id
        // Count only the drills this player can actually open. Putting the
        // locked DUPR IQ Pro set in the denominator would mean a free player's ring
        // can never close, which is a nag dressed up as progress.
        let open = court.drills.filter { !court.isLocked($0, isMember: subscriptions.isPro) }
        let total = open.count
        let done = open.filter { progress.completions(for: $0.id) > 0 }.count
        return NavigationLink {
            CourtView(court: court)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: court.icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(court.accent)
                    .frame(width: 48, height: 48)
                    .background(court.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(court.name)
                            .font(.headline)
                            .foregroundStyle(Theme.ink)
                        if locked {
                            PlusBadge()
                        }
                    }
                    Text(court.tagline)
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 4)
                if locked {
                    Image(systemName: "lock.fill")
                        .font(.footnote)
                        .foregroundStyle(Theme.gold)
                } else {
                    ProgressRing(done: done, total: total, color: court.accent)
                }
            }
            .padding(14)
            .themedCard()
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous)
                    .strokeBorder(highlighted ? court.accent : Color.clear, lineWidth: 2.5)
            )
            .contentShape(RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous))
        }
        .buttonStyle(PressableCardStyle())
        .accessibilityHint(locked
            ? "Locked. \(total) drills, included with \(Membership.name)"
            : "\(done) of \(total) drills done")
        .id(court.id)
    }

    private var upgradeCard: some View {
        Button {
            showPaywall = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.gold)
                    .frame(width: 38, height: 38)
                    .background(Theme.gold.opacity(0.14), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("Get \(Membership.name)")
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                    Text("Targeted review, timed practice, and \(lockedDrillCount) more drills across the focused courts")
                        .font(.caption)
                        .foregroundStyle(Theme.inkSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.inkTertiary)
            }
            .padding(12)
            .themedCard(corner: 16)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Theme.gold.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(PressableCardStyle())
        .padding(.top, 2)
    }

    private var lockedDrillCount: Int {
        DrillLibrary.courts.reduce(0) { $0 + $1.plusDrillCount }
    }

    private var disclaimerFooter: some View {
        Text("A coaching aid. Shot selection is opinion, and every answer here names the principle it came from so you can weigh it yourself. \(ShellCopy.Legal.duprDisclaimer)")
            .font(.caption2)
            .foregroundStyle(Theme.inkTertiary)
            .multilineTextAlignment(.center)
            .padding(.top, 8)
    }
}

/// Court completion at a glance: a ring that fills as the court's drills get
/// done, and becomes a seal once they all are.
struct ProgressRing: View {
    let done: Int
    let total: Int
    var color: Color

    private var fraction: Double {
        guard total > 0 else { return 0 }
        return Double(done) / Double(total)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.18), lineWidth: 3)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: fraction)
            if done == total, total > 0 {
                Image(systemName: "checkmark")
                    .font(.caption2.weight(.black))
                    .foregroundStyle(color)
            } else {
                Text("\(done)/\(total)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.inkSecondary)
                    .monospacedDigit()
            }
        }
        .frame(width: 32, height: 32)
        .accessibilityHidden(true)
    }
}

extension DrillKind {
    var symbol: String {
        switch self {
        case .flashcards: return "rectangle.stack.fill"
        case .quiz: return "questionmark.circle.fill"
        case .principleMatch: return "quote.bubble.fill"
        case .worked: return "figure.pickleball"
        }
    }

    var unitName: String {
        switch self {
        case .flashcards: return "cards"
        case .quiz: return "questions"
        case .principleMatch: return "scenarios"
        case .worked: return "worked reads"
        }
    }
}
