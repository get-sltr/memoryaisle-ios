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

    private var updateTask: Task<Void, Never>?

    init() {
        // Honour the App Reviewer override at construction time so any
        // gating decision made before `updateSubscriptionStatus()` runs
        // still treats the reviewer device as Pro.
        if AppReviewerSeedService.isMarkedAsReviewer {
            tier = .pro
        }
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

    /// Re-evaluates the local Pro flag from `AppReviewerSeedService` so a
    /// just-signed-in reviewer flips to Pro tier immediately, without
    /// waiting for the next StoreKit refresh.
    func refreshOverrides() {
        if AppReviewerSeedService.isMarkedAsReviewer {
            tier = .pro
        }
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
            products = try await Product.products(for: [Self.proAnnualID])
        } catch {
            products = []
        }
        isLoading = false
    }

    // MARK: - Purchase

    func purchase() async throws -> Bool {
        guard let product = products.first else { return false }

        let result = try await product.purchase()

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
        let hasPaidPro = activePurchases.contains(Self.proAnnualID)
        let hasReviewerPro = AppReviewerSeedService.isMarkedAsReviewer
        tier = (hasPaidPro || hasReviewerPro) ? .pro : .free
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
