import XCTest
@testable import DuprIQ

/// The contract for the authored courts and the shell that frames them.
///
/// `PositionGeneratorTests` and `ShotAdvisorTests` pin the generator. Nothing
/// pinned the authored library or the chrome around it, and this app's shell
/// was ported from another app in the fleet, so the two failure modes worth a
/// suite of their own are: a question that cannot be answered correctly, and a
/// leftover word from the previous domain surfacing somewhere no drill test
/// would ever look.
final class ContentTests: XCTestCase {

    // MARK: - Structure

    func testCourtAndDrillIDsAreUnique() {
        var courtIDs: Set<String> = []
        var drillIDs: Set<String> = []
        for court in DrillLibrary.courts {
            XCTAssertTrue(courtIDs.insert(court.id).inserted, "duplicate court id \(court.id)")
            for drill in court.drills {
                XCTAssertTrue(drillIDs.insert(drill.id).inserted, "duplicate drill id \(drill.id)")
            }
        }
    }

    func testItemIDsAreUniqueAcrossTheWholeLibrary() {
        var seen: Set<String> = []
        for item in SessionBuilder.choicePool(includePro: true) {
            XCTAssertTrue(seen.insert(item.id).inserted, "duplicate item id \(item.id)")
        }
    }

    /// Two free courts is a promise the paywall copy, the tour and the marketing
    /// page all repeat. If a court's `isFree` flips, this is the cheapest place
    /// to find out.
    func testTwoCourtsAreFree() {
        XCTAssertEqual(DrillLibrary.courts.filter(\.isFree).count, 2)
    }

    func testEveryCourtHasDrillsAndEveryDrillHasItems() {
        for court in DrillLibrary.courts {
            XCTAssertFalse(court.drills.isEmpty, "\(court.id) has no drills")
            for drill in court.drills {
                XCTAssertGreaterThan(drill.kind.itemCount, 0, "\(drill.id) is empty")
            }
        }
    }

    /// Every phase has to land in a court that exists, because the stats
    /// breakdown looks its label up by that id and silently shows nothing when
    /// it misses.
    func testEveryPhaseMapsToARealCourt() {
        let ids = Set(DrillLibrary.courts.map(\.id))
        for phase in RallyPhase.allCases {
            XCTAssertTrue(ids.contains(phase.courtID), "\(phase.rawValue) points at \(phase.courtID)")
        }
    }

    // MARK: - Answerability

    func testEveryChoiceItemIsAnswerable() {
        for item in SessionBuilder.choicePool(includePro: true) {
            XCTAssertGreaterThanOrEqual(item.choices.count, 2, "\(item.id) has too few choices")
            XCTAssertTrue(item.choices.indices.contains(item.answerIndex), "\(item.id) answer out of range")
            XCTAssertEqual(Set(item.choices).count, item.choices.count, "\(item.id) repeats a choice")
            XCTAssertFalse(item.prompt.isEmpty, "\(item.id) has no prompt")
            XCTAssertFalse(item.explanation.isEmpty, "\(item.id) has no explanation")
        }
    }

    func testPrincipleMatchAnswersAreAmongTheirChoices() {
        let questions = PrincipleContent.principleMatch + PlusContent.principleExtras
        for question in questions {
            XCTAssertTrue(
                question.choices.contains(question.answer),
                "\(question.id) does not offer its own answer"
            )
            XCTAssertEqual(Set(question.choices).count, question.choices.count, "\(question.id) repeats a choice")
        }
    }

    /// The property that makes the Worked Reads court safe to author.
    ///
    /// Its positions come from pinned generator seeds rather than hand-built
    /// coordinates, so the answer it teaches is by construction the answer the
    /// app grades. A worked example that disagreed with `ShotAdvisor` would be
    /// worse than no worked example at all, and a hand-written position would
    /// eventually drift into exactly that.
    func testWorkedReadsAgreeWithTheAdvisor() {
        for read in TransitionContent.workedReads {
            XCTAssertTrue(read.choices.indices.contains(read.answerIndex), "\(read.id) answer out of range")
            let verdict = ShotAdvisor.verdict(for: read.position)
            XCTAssertEqual(
                read.choices[read.answerIndex],
                verdict.best.label,
                "\(read.id) teaches a different shot than the advisor grades"
            )
            XCTAssertEqual(read.principle, verdict.principle, "\(read.id) names the wrong principle")
            XCTAssertFalse(read.steps.isEmpty, "\(read.id) has no read to show")
        }
    }

    /// The steps are the court's whole value. A worked read whose steps got
    /// dropped renders as a bare answer, which is what the authored court exists
    /// not to be.
    func testWorkedReadsShowTheirWorking() {
        for read in TransitionContent.workedReads {
            XCTAssertGreaterThanOrEqual(read.steps.count, 3, "\(read.id) skips most of the read")
        }
    }

    // MARK: - Generated items

    func testGeneratedItemsCarryACourtAndAnAnswer() {
        for phase in RallyPhase.allCases {
            let item = EndlessPractice.item(phase: phase, seed: 4_242)
            XCTAssertNotNil(item.position, "\(phase.rawValue) generated no court")
            XCTAssertEqual(item.position?.phase, phase)
            XCTAssertTrue(item.choices.indices.contains(item.answerIndex))
            XCTAssertEqual(item.phase, phase)
            XCTAssertFalse(item.steps.isEmpty, "\(phase.rawValue) generated no read")
        }
    }

    /// An unbounded stream of one-off ids must not grow the record store
    /// forever, so every generated ball in a phase reports to one row.
    func testGeneratedItemsRollUpToOneTrackingRowPerPhase() {
        let ids = Set((0..<25).map { EndlessPractice.item(phase: .dinkRally, seed: UInt64($0)).trackingID })
        XCTAssertEqual(ids.count, 1)
        XCTAssertEqual(ids.first, RallyPhase.dinkRally.itemPrefix + "rollup")
    }

    func testGeneratedItemsAreNotSchedulableForReview() {
        // Their id will never be seen again, so scheduling the ITEM would be
        // meaningless. The mistake pattern is what comes back instead.
        let item = EndlessPractice.item(phase: .attack, seed: 9)
        XCTAssertFalse(item.isReviewable)
    }

    func testEveryPhaseCanProduceANamedMistake() {
        // Not every position sets a trap, but every phase must be able to, or
        // Fix My Mistakes has nothing to aim at for that phase.
        for phase in RallyPhase.allCases {
            let named = (0..<40).contains { seed in
                !EndlessPractice.item(phase: phase, seed: UInt64(seed)).mistakes.isEmpty
            }
            XCTAssertTrue(named, "\(phase.rawValue) never names a mistake")
        }
    }

    func testTargetedItemsComeBackInTheRightPhase() {
        let pattern = MistakePattern(
            id: "attacked-a-low-ball",
            phase: RallyPhase.dinkRally.rawValue,
            summary: "test"
        )
        let items = EndlessPractice.targetedItems(for: [pattern], count: 4, seed: 77)
        XCTAssertEqual(items.count, 4)
        for item in items {
            XCTAssertEqual(item.phase, .dinkRally)
        }
    }

    // MARK: - Daily drill

    func testDailyDrillIsTheSameForEveryReaderOnAGivenDay() {
        let day = Date(timeIntervalSince1970: 1_800_000_000)
        let first = DailyDrillContent.challenge(for: day)
        let second = DailyDrillContent.challenge(for: day)
        XCTAssertEqual(first.dayKey, second.dayKey)
        XCTAssertEqual(first.items.map(\.id), second.items.map(\.id))
        XCTAssertEqual(first.items.map(\.answerIndex), second.items.map(\.answerIndex))
    }

    func testDailyDrillIsFull() {
        let challenge = DailyDrillContent.challenge(for: Date(timeIntervalSince1970: 1_800_000_000))
        XCTAssertEqual(challenge.questions.count, DailyDrillContent.questionCount)
    }

    /// The day boundary is fixed rather than local, or two readers either side
    /// of midnight get different sets while claiming the same day.
    func testDailyDrillDayBoundaryIsFixed() {
        XCTAssertEqual(DailyDrillContent.dayCalendar.timeZone.identifier, "America/Los_Angeles")
    }

    // MARK: - Entitlement

    func testFreePoolIsASubsetOfTheProPool() {
        let free = Set(SessionBuilder.choicePool(includePro: false).map(\.id))
        let pro = Set(SessionBuilder.choicePool(includePro: true).map(\.id))
        XCTAssertTrue(free.isSubset(of: pro))
        XCTAssertLessThan(free.count, pro.count, "Pro unlocks nothing")
    }

    func testFreePoolContainsNoPaidCourtItems() {
        let paidCourtIDs = Set(DrillLibrary.courts.filter { !$0.isFree }.map(\.id))
        for item in SessionBuilder.choicePool(includePro: false) {
            XCTAssertFalse(paidCourtIDs.contains(item.courtID), "\(item.id) leaked from a paid court")
        }
    }

    // MARK: - Port residue
    //
    // The shell came from another app. These are the words that would prove it.

    /// Vocabulary from the apps this shell passed through, plus the exam-prep
    /// framing it was written for. None of it belongs in a pickleball app, and
    /// none of it would be caught by a test that only reads drill answers.
    /// Matched on WORD BOUNDARIES, not as substrings. The first version of
    /// this test used `contains` and failed on "tiebreaker", which is both a
    /// perfectly good pickleball word and proof that a substring scan over
    /// English prose reports mostly noise.
    private static let foreignWords = [
        "ampacity", "conductor", "conductors", "raceway", "breaker", "breakers",
        "overcurrent", "grounding", "conduit", "NEC", "code book", "journeyman",
        "electrician", "wireman",
        "mah jongg", "mahjong", "charleston", "tile", "tiles", "rack", "joker",
        "trick-taking", "skat", "declarer",
        "exam", "candidate", "licence", "license",
    ]

    func testShellCopyCarriesNoForeignVocabulary() {
        assertNoForeignWords(in: ShellCopy.all, label: "ShellCopy")
    }

    func testAuthoredContentCarriesNoForeignVocabulary() {
        var strings: [String] = []
        for item in SessionBuilder.choicePool(includePro: true) {
            strings.append(item.prompt)
            strings.append(item.explanation)
            strings += item.choices
            if let principle = item.principle { strings.append(principle) }
        }
        for read in TransitionContent.workedReads {
            strings.append(read.situation)
            strings += read.steps
            strings += read.choices
        }
        for page in HowToPlayContent.pages {
            strings.append(page.title)
            strings.append(page.body)
            if let tip = page.tip { strings.append(tip) }
        }
        for principle in Principle.allCases {
            strings.append(principle.displayName)
            strings.append(principle.howToSpot)
            strings.append(principle.tag)
        }
        assertNoForeignWords(in: strings, label: "authored content")
    }

    func testFlashcardBackscarryNoForeignVocabulary() {
        let cards = CourtBasicsContent.courtCards
            + KitchenContent.dinkCards
            + TransitionContent.thirdShotCards
            + ProContent.attackCards
            + ProContent.defenseCards
            + PrincipleContent.principleCards
        var strings: [String] = []
        for card in cards {
            strings.append(card.frontTitle)
            strings.append(card.backTitle)
            strings.append(card.backBody)
            if let subtitle = card.frontSubtitle { strings.append(subtitle) }
        }
        assertNoForeignWords(in: strings, label: "flashcards")
    }

    /// The app is not affiliated with Dynamic Universal Pickleball Rating, and
    /// the disclaimer that says so has to survive every redesign.
    func testTrademarkDisclaimerExists() {
        XCTAssertTrue(ShellCopy.all.contains(ShellCopy.Legal.duprDisclaimer))
        XCTAssertTrue(ShellCopy.Legal.duprDisclaimer.contains("Not affiliated"))
    }

    /// Nothing in the app may claim to report or require an official rating.
    func testNothingClaimsToReportAnOfficialRating() {
        var strings = ShellCopy.all
        strings += ExperienceLevel.allCases.map(\.title)
        strings += ExperienceLevel.allCases.map(\.detail)
        strings += ExperienceLevel.allCases.map(\.emphasis)
        for text in strings {
            let lower = text.lowercased()
            XCTAssertFalse(lower.contains("your dupr"), "claims a rating: \(text)")
            XCTAssertFalse(lower.contains("dupr rating"), "claims a rating: \(text)")
        }
    }

    // MARK: - Principles

    func testPrincipleShortNamesAreUniqueAndPopulated() {
        var names: Set<String> = []
        for principle in Principle.allCases {
            XCTAssertFalse(principle.shortName.isEmpty)
            XCTAssertFalse(principle.tag.isEmpty)
            XCTAssertFalse(principle.howToSpot.isEmpty)
            XCTAssertTrue(names.insert(principle.shortName).inserted, "duplicate \(principle.shortName)")
        }
    }

    // MARK: - Helper

    private func assertNoForeignWords(
        in strings: [String],
        label: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        for text in strings {
            for word in Self.foreignWords where Self.containsWord(word, in: text) {
                XCTFail("\(label) still says \"\(word)\": \(text)", file: file, line: line)
            }
        }
    }

    private static func containsWord(_ word: String, in text: String) -> Bool {
        let pattern = "\\b\(NSRegularExpression.escapedPattern(for: word))\\b"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return false
        }
        let range = NSRange(text.startIndex..., in: text)
        return regex.firstMatch(in: text, range: range) != nil
    }
}
