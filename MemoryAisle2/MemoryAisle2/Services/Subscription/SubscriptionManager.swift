import StoreKit
import SwiftUI

enum SubscriptionTier {
    case free
    case pro
}

@MainActor
@Observable
final class SubscriptionManager {
    private(set) var tier: SubscriptionTier = .free
    private(set) var products: [Product] = []
    private(set) var purchasedProductIDs: Set<String> = []
    private(set) var isLoading = false

    static let proAnnualID = "com.sltrdigital.memoryaisle.pro.annual"
    static let proMonthlyID = "com.sltrdigital.memoryaisle.pro.monthly"
    static let proProductIDs: Set<String> = [proAnnualID, proMonthlyID]

    private var updateTask: Task<Void, Never>?

    init() {
        // StoreKit 2 requires a Task iterating Transaction.updates to be
        // active from app launch, otherwise async transaction outcomes
        // (Ask-to-Buy approvals, background renewals, refunds) are lost
        // and Xcode logs a runtime warning under StoreKit.
        startListening()
        // Query Transaction.currentEntitlements at launch so a reinstalled
        // app recognizes an existing Apple ID subscription before the user
        // hits a Pro gate. Without this, tier stays .free until the paywall
        // happens to appear and its .task runs updateSubscriptionStatus().
        Task { await updateSubscriptionStatus() }
    }

    func startListening() {
        updateTask = Task {
            await listenForTransactions()
        }
    }

    func stopListening() {
        updateTask?.cancel()
    }

    // MARK: - Load Products

    func loadProducts() async {
        isLoading = true
        do {
            products = try await Product.products(for: Self.proProductIDs)
        } catch {
            products = []
        }
        isLoading = false
    }

    // MARK: - Purchase

    func purchase(productID: String, appAccountToken: UUID? = nil) async throws -> Bool {
        guard let product = products.first(where: { $0.id == productID }) else { return false }

        // Tag the transaction with the signed-in user's Cognito UUID so
        // App Store Server Notifications can be correlated back to this
        // account. Callers pass nil when no session exists, in which
        // case StoreKit treats it as an anonymous purchase.
        var options: Set<Product.PurchaseOption> = []
        if let appAccountToken {
            options.insert(.appAccountToken(appAccountToken))
        }

        let result = try await product.purchase(options: options)

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            await updateSubscriptionStatus()
            return true

        case .userCancelled:
            return false

        case .pending:
            return false

        @unknown default:
            return false
        }
    }

    // MARK: - Restore

    func restore() async {
        try? await AppStore.sync()
        await updateSubscriptionStatus()
    }

    // MARK: - Status

    func updateSubscriptionStatus() async {
        var activePurchases: Set<String> = []

        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result) {
                activePurchases.insert(transaction.productID)
            }
        }

        purchasedProductIDs = activePurchases
        tier = Self.computeTier(activePurchases: activePurchases)
    }

    // Pure tier-computation so the entitlement math can be exercised in
    // unit tests without standing up StoreKit. The user is Pro iff any
    // of the known Pro product IDs are in their active purchase set.
    static func computeTier(activePurchases: Set<String>) -> SubscriptionTier {
        activePurchases.isDisjoint(with: proProductIDs) ? .free : .pro
    }

    // The StoreKit Product for the user's currently active subscription,
    // or nil if they have none. Lets ProBenefitsView render the actual
    // plan (price, period) rather than hardcoding annual.
    var activeProduct: Product? {
        products.first { purchasedProductIDs.contains($0.id) }
    }

    // Canonical auto-renewal disclosure copy required by Apple guideline
    // 3.1.2. Both the pre-purchase paywall and the post-purchase benefits
    // screen render this string; keeping it here guarantees they can't
    // drift into saying different things about billing. Price is
    // interpolated from the live Product so non-US locales see their
    // actual charge, not a hardcoded USD value.
    static func legalCopy(productID: String, displayPrice: String) -> String {
        let period = productID == proMonthlyID ? "month" : "year"
        return "MemoryAisle Pro is a \(displayPrice)/\(period) auto-renewable subscription. Payment will be charged to your Apple ID at confirmation of purchase. The subscription automatically renews at \(displayPrice) per \(period) unless auto-renew is turned off at least 24 hours before the end of the current period. Your account will be charged for renewal within 24 hours prior to the end of the current period. You can manage your subscription and turn off auto-renewal at any time in Settings \u{203a} Apple ID \u{203a} Subscriptions."
    }

    // MARK: - Transaction Listener

    private func listenForTransactions() async {
        for await result in Transaction.updates {
            if let transaction = try? checkVerified(result) {
                await transaction.finish()
                await updateSubscriptionStatus()
            }
        }
    }

    // MARK: - Verification

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let value):
            return value
        }
    }

    // MARK: - Limits

    var barcodeScanLimit: Int {
        tier == .pro ? .max : 3
    }

    var miraMessageLimit: Int {
        tier == .pro ? .max : 10
    }

    var hasUnlimitedMeals: Bool {
        tier == .pro
    }

    var hasWidgets: Bool {
        tier == .pro
    }

    var hasProviderReport: Bool {
        tier == .pro
    }

    var hasBodyComp: Bool {
        tier == .pro
    }
}

enum StoreError: Error {
    case failedVerification
}
