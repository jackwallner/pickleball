import RevenueCat
import XCTest
@testable import DuprIQ

/// What the paywall shows when a purchase does not go through.
final class PurchaseErrorTests: XCTestCase {

    /// Ask to Buy reads as waiting, not as a failure.
    func testAskToBuyIsShownAsWaitingForApproval() {
        let shown = PurchaseError.shown(RevenueCat.ErrorCode.paymentPendingError)
        XCTAssertEqual(shown as? PurchaseError, .waitingForApproval)
        XCTAssertEqual(
            shown.localizedDescription,
            "Waiting for approval. Your purchase unlocks once it is approved."
        )
    }

    func testALostConnectionReadsAsTheAppStoreLine() {
        for code in [RevenueCat.ErrorCode.networkError, .offlineConnectionError] {
            let shown = PurchaseError.shown(code)
            XCTAssertEqual(shown as? PurchaseError, .productsUnavailable, "\(code)")
            XCTAssertEqual(
                shown.localizedDescription,
                "The App Store isn't reachable right now. Check your connection and try again."
            )
        }
    }

    func testOtherErrorsPassThroughUnchanged() {
        let other = RevenueCat.ErrorCode.purchaseNotAllowedError
        XCTAssertEqual(PurchaseError.shown(other) as? RevenueCat.ErrorCode, other)
        XCTAssertEqual(PurchaseError.shown(PurchaseError.productsUnavailable) as? PurchaseError, .productsUnavailable)
        let foreign = NSError(domain: "test", code: 7)
        XCTAssertEqual(PurchaseError.shown(foreign) as NSError, foreign)
    }
}
