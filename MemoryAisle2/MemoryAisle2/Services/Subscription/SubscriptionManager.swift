import StoreKit
import SwiftUI

enum SubscriptionTier {
    case free
    case pro
}

@Observable
final class SubscriptionManager {
    private(set) var tier: SubscriptionTier = .free
    private(set) var products: [Product] = []
    private(set) var purchasedProductIDs: Set<String> = []
    private(set) var isLoading = false

    static let proYearlyID = "com.sltrdigital.memoryaisle.pro.yearly"

    private var updateTask: Task<Void, Never>?

    init() {
        updateTask = Task { [weak self] in
            await self?.listenForTransactions()
        }
    }

    deinit {
        updateTask?.cancel()
    }

    // MARK: - Load Products

    func loadProducts() async {
        isLoading = true
        do {
            products = try await Product.products(for: [Self.proYearlyID])
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
        tier = activePurchases.contains(Self.proYearlyID) ? .pro : .free
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
