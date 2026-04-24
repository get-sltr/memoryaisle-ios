import CryptoKit
import Foundation
import SwiftData

/// Builds a per-user SwiftData ModelContainer so every signed-in user's
/// data lives in its own physical file on disk. Different users on the
/// same device cannot see each other's data because they are operating
/// on different containers; nothing is ever deleted — when a user signs
/// out, their container stays on disk untouched, ready to load again
/// next time they sign in.
///
/// The anonymous container (used before any user has signed in) lives
/// at the SwiftData default location. Every user container lives under
/// `Application Support/MemoryAisle/Users/<hash>/default.store`, where
/// `<hash>` is a SHA-256-derived suffix of the user's stable identifier
/// (Cognito `sub` for email/password users, the Apple user ID for SIWA
/// users). Hashing keeps the identifier out of the filesystem path.
enum UserDataContainer {

    /// Model types that belong in the per-user container. Everything
    /// the app persists — including Reflection / SafeSpace models —
    /// lives here; per-user scoping at the container layer gives
    /// Reflection the privacy guarantee it needs without requiring a
    /// separate store.
    static let models: [any PersistentModel.Type] = [
        UserProfile.self,
        NutritionLog.self,
        SymptomLog.self,
        PantryItem.self,
        GIToleranceRecord.self,
        MealPlan.self,
        Meal.self,
        FoodItem.self,
        GroceryList.self,
        MedicationProfile.self,
        TrainingSession.self,
        BodyComposition.self,
        ProviderReport.self,
        SavedRecipe.self
    ]

    /// Build a container for a specific user identifier. Passing nil
    /// returns the anonymous container used before sign-in, so the
    /// welcome / auth flow can still touch a working store without
    /// leaking any user's data into it.
    static func make(for userIdentifier: String?) throws -> ModelContainer {
        let schema = Schema(models)
        let config: ModelConfiguration
        if let userIdentifier {
            let url = try storeURL(for: userIdentifier)
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            config = ModelConfiguration(schema: schema, url: url)
        } else {
            config = ModelConfiguration(schema: schema)
        }
        return try ModelContainer(for: schema, configurations: [config])
    }

    /// Resolves the stable identifier used to key the container. Prefers
    /// the Cognito `sub` (which email/password sign-ins mint), falls
    /// back to the Apple user ID for SIWA sessions, and returns nil if
    /// no session is active.
    static func currentIdentifier() -> String? {
        if let uuid = CognitoAuthManager.currentUserUUID() {
            return uuid.uuidString
        }
        if let appleID = UserDefaults.standard.string(forKey: "ma_apple_user_id") {
            return appleID
        }
        return nil
    }

    private static func storeURL(for userIdentifier: String) throws -> URL {
        let appSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return appSupport
            .appendingPathComponent("MemoryAisle")
            .appendingPathComponent("Users")
            .appendingPathComponent(hash(userIdentifier))
            .appendingPathComponent("default.store")
    }

    /// Short SHA-256 prefix of the user identifier — stable across
    /// launches, filesystem-safe, non-reversible enough to keep the raw
    /// identifier out of the path. 16 hex chars is 64 bits; collisions
    /// on a single device are not a realistic concern.
    private static func hash(_ input: String) -> String {
        let digest = SHA256.hash(data: Data(input.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return String(hex.prefix(16))
    }
}
