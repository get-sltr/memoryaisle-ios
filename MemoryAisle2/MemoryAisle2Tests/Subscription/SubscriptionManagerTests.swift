import XCTest
@testable import MemoryAisle2

/// SubscriptionManager tests. Covers the pure tier-computation rule
/// (the user is Pro iff any Pro product ID is in their active purchase
/// set) and the canonical auto-renewal disclosure string required by
/// App Store guideline 3.1.2. Wiring the live StoreKit APIs into a test
/// harness is a separate ask; this suite guards the logic users
/// actually experience as "am I Pro" and "does the paywall say the
/// right thing about billing."
@MainActor
final class SubscriptionManagerTests: XCTestCase {

    // MARK: - computeTier

    func test_computeTier_emptyPurchases_isFree() {
        let tier = SubscriptionManager.computeTier(activePurchases: [])
        XCTAssertEqual(tier, .free)
    }

    func test_computeTier_annualOnly_isPro() {
        let tier = SubscriptionManager.computeTier(
            activePurchases: [SubscriptionManager.proAnnualID]
        )
        XCTAssertEqual(tier, .pro)
    }

    func test_computeTier_monthlyOnly_isPro() {
        let tier = SubscriptionManager.computeTier(
            activePurchases: [SubscriptionManager.proMonthlyID]
        )
        XCTAssertEqual(tier, .pro)
    }

    func test_computeTier_bothAnnualAndMonthly_isPro() {
        let tier = SubscriptionManager.computeTier(
            activePurchases: [
                SubscriptionManager.proAnnualID,
                SubscriptionManager.proMonthlyID
            ]
        )
        XCTAssertEqual(tier, .pro)
    }

    func test_computeTier_unknownProductID_isFree() {
        let tier = SubscriptionManager.computeTier(
            activePurchases: ["com.other.app.subscription"]
        )
        XCTAssertEqual(tier, .free)
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
