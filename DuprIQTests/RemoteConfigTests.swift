import XCTest
@testable import DuprIQ

/// Offering metadata: the trial button's wording test and the off switches.
final class RemoteConfigTests: XCTestCase {

    func testMissingNonStringAndUnknownValuesAreTheControl() {
        XCTAssertEqual(TrialCTA.from(metadata: nil), .sevenDay)
        XCTAssertEqual(TrialCTA.from(metadata: [:]), .sevenDay)
        XCTAssertEqual(TrialCTA.from(metadata: ["trial_cta": 1]), .sevenDay)
        XCTAssertEqual(TrialCTA.from(metadata: ["trial_cta": ["my"]]), .sevenDay)
        XCTAssertEqual(TrialCTA.from(metadata: ["trial_cta": "ours"]), .sevenDay)
        XCTAssertEqual(TrialCTA.from(metadata: ["trial_cta": "MY"]), .sevenDay)
    }

    func testEachKnownValueSelectsItsArm() {
        XCTAssertEqual(TrialCTA.metadataKey, "trial_cta")
        XCTAssertEqual(TrialCTA.from(metadata: ["trial_cta": "seven_day"]), .sevenDay)
        XCTAssertEqual(TrialCTA.from(metadata: ["trial_cta": "my"]), .my)
        XCTAssertEqual(TrialCTA.from(metadata: ["trial_cta": "your"]), .your)
    }

    /// The control is the paywall's button copy from before the reader,
    /// character for character, so a customer outside a test sees no change.
    func testTheControlIsTheShippedButtonCopy() {
        XCTAssertEqual(TrialCTA.sevenDay.title, "Start free trial")
        XCTAssertEqual(TrialCTA.sevenDay.title(trialEligible: true), "Start free trial")
    }

    func testEachArmsTitle() {
        XCTAssertEqual(TrialCTA.my.title(trialEligible: true), "Start my free trial")
        XCTAssertEqual(TrialCTA.your.title(trialEligible: true), "Start your free trial")
    }

    /// No arm promises a trial to an account that cannot have one (3.1.2).
    func testIneligibleWordingIsUnchangedInEveryArm() {
        for arm in TrialCTA.allCases {
            XCTAssertEqual(arm.title(trialEligible: false), "Subscribe", "\(arm)")
        }
    }

    func testASwitchIsOnUnlessTheValueIsOff() {
        XCTAssertEqual(RemoteSwitch.ratingPrompt.rawValue, "rating_prompt")
        XCTAssertTrue(RemoteConfig.isOn(.ratingPrompt, in: nil))
        XCTAssertTrue(RemoteConfig.isOn(.ratingPrompt, in: [:]))
        XCTAssertTrue(RemoteConfig.isOn(.ratingPrompt, in: ["rating_prompt": "on"]))
        XCTAssertTrue(RemoteConfig.isOn(.ratingPrompt, in: ["rating_prompt": false]))
        XCTAssertTrue(RemoteConfig.isOn(.ratingPrompt, in: ["rating_prompt": "OFF"]))
        XCTAssertFalse(RemoteConfig.isOn(.ratingPrompt, in: ["rating_prompt": "off"]))
    }
}
