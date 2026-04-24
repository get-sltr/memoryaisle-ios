import XCTest
@testable import MemoryAisle2

/// SubscriptionManager tests. Covers the pure tier-computation rule
/// (reviewer override wins; otherwise any Pro product ID in the active
/// purchase set flips the user to Pro) and the canonical auto-renewal
/// disclosure string required by App Store guideline 3.1.2. Wiring the
/// live StoreKit APIs into a test harness is a separate ask; this suite
/// guards the logic users actually experience as "am I Pro" and "does
/// the paywall say the right thing about billing."
@MainActor
final class SubscriptionManagerTests: XCTestCase {

    // MARK: - computeTier

    func test_computeTier_emptyPurchases_notReviewer_isFree() {
        let tier = SubscriptionManager.computeTier(
            activePurchases: [],
            isReviewer: false
        )
        XCTAssertEqual(tier, .free)
    }

    func test_computeTier_emptyPurchases_isReviewer_isPro() {
        let tier = SubscriptionManager.computeTier(
            activePurchases: [],
            isReviewer: true
        )
        XCTAssertEqual(tier, .pro)
    }

    func test_computeTier_annualOnly_isPro() {
        let tier = SubscriptionManager.computeTier(
            activePurchases: [SubscriptionManager.proAnnualID],
            isReviewer: false
        )
        XCTAssertEqual(tier, .pro)
    }

    func test_computeTier_monthlyOnly_isPro() {
        let tier = SubscriptionManager.computeTier(
            activePurchases: [SubscriptionManager.proMonthlyID],
            isReviewer: false
        )
        XCTAssertEqual(tier, .pro)
    }

    func test_computeTier_bothAnnualAndMonthly_isPro() {
        let tier = SubscriptionManager.computeTier(
            activePurchases: [
                SubscriptionManager.proAnnualID,
                SubscriptionManager.proMonthlyID
            ],
            isReviewer: false
        )
        XCTAssertEqual(tier, .pro)
    }

    func test_computeTier_unknownProductID_isFree() {
        let tier = SubscriptionManager.computeTier(
            activePurchases: ["com.other.app.subscription"],
            isReviewer: false
        )
        XCTAssertEqual(tier, .free)
    }

    func test_computeTier_annualAndReviewer_isPro() {
        // Reviewer flag plus a real purchase should still resolve to .pro;
        // the flag is a shortcut, not a blocker for paying users.
        let tier = SubscriptionManager.computeTier(
            activePurchases: [SubscriptionManager.proAnnualID],
            isReviewer: true
        )
        XCTAssertEqual(tier, .pro)
    }

    // MARK: - proProductIDs membership

    func test_proProductIDs_containsBothPlans() {
        XCTAssertTrue(SubscriptionManager.proProductIDs.contains(SubscriptionManager.proAnnualID))
        XCTAssertTrue(SubscriptionManager.proProductIDs.contains(SubscriptionManager.proMonthlyID))
        XCTAssertEqual(SubscriptionManager.proProductIDs.count, 2)
    }

    // MARK: - legalCopy (Apple 3.1.2 disclosure)

    func test_legalCopy_annual_containsRequiredDisclosures() {
        let copy = SubscriptionManager.legalCopy(
            productID: SubscriptionManager.proAnnualID,
            displayPrice: "$49.99"
        )
        XCTAssertTrue(copy.contains("$49.99/year"), "Price and period must be stated")
        XCTAssertTrue(copy.contains("auto-renewable subscription"), "Length must be stated")
        XCTAssertTrue(copy.contains("at confirmation of purchase"), "Charge timing must be stated")
        XCTAssertTrue(copy.contains("automatically renews at $49.99 per year"), "Renewal cost must be stated")
        XCTAssertTrue(copy.contains("at least 24 hours before the end of the current period"), "Cancel cutoff must be stated")
        XCTAssertTrue(copy.contains("within 24 hours prior to the end of the current period"), "Renewal charge window must be stated")
        XCTAssertTrue(copy.contains("Settings"), "Management path must be stated")
    }

    func test_legalCopy_monthly_containsRequiredDisclosures() {
        let copy = SubscriptionManager.legalCopy(
            productID: SubscriptionManager.proMonthlyID,
            displayPrice: "$9.99"
        )
        XCTAssertTrue(copy.contains("$9.99/month"))
        XCTAssertTrue(copy.contains("auto-renewable subscription"))
        XCTAssertTrue(copy.contains("at confirmation of purchase"))
        XCTAssertTrue(copy.contains("automatically renews at $9.99 per month"))
        XCTAssertTrue(copy.contains("at least 24 hours before the end of the current period"))
        XCTAssertTrue(copy.contains("within 24 hours prior to the end of the current period"))
        XCTAssertTrue(copy.contains("Settings"))
    }

    func test_legalCopy_usesLocalizedDisplayPrice() {
        // International users see the localized price in the disclosure,
        // not a hardcoded USD value.
        let copy = SubscriptionManager.legalCopy(
            productID: SubscriptionManager.proAnnualID,
            displayPrice: "€49,99"
        )
        XCTAssertTrue(copy.contains("€49,99/year"))
        XCTAssertFalse(copy.contains("$49.99"))
    }
}
