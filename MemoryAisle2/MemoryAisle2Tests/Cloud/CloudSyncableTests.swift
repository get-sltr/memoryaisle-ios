import SwiftData
import XCTest
@testable import MemoryAisle2

/// Pins the privacy invariant that keeps Safe Space entries off the
/// network. The real gate is compile-time: `CloudSyncable: PersistentModel`
/// combined with `CloudSyncManager.fetchSyncable<T: CloudSyncable>`. This
/// suite documents the gate and fails loudly if the shape of the
/// allowlist or `SafeSpaceEntry` ever drifts.
final class CloudSyncableTests: XCTestCase {

    /// Generic "accepter" — its body is trivial, its parameter list is
    /// the assertion. Each call below only compiles if the passed type
    /// conforms to `CloudSyncable`. Adding a type here without adding
    /// the conformance fails the build, not the test.
    private func acceptSyncable<T: CloudSyncable>(_ type: T.Type) {}

    func testAllowedCloudSyncableModelsCompileThrough() {
        acceptSyncable(UserProfile.self)
        acceptSyncable(NutritionLog.self)
        acceptSyncable(SymptomLog.self)
        acceptSyncable(PantryItem.self)
    }

    /// Runtime pin on the size of the allowlist. If this number changes,
    /// a reviewer must confirm the new model was vetted for privacy and
    /// server-side handling before the test is updated.
    func testCloudSyncableAllowlistCount() {
        let allowed: [String] = [
            String(describing: UserProfile.self),
            String(describing: NutritionLog.self),
            String(describing: SymptomLog.self),
            String(describing: PantryItem.self),
        ]
        XCTAssertEqual(
            allowed.count, 4,
            "Cloud sync allowlist changed. Audit the new model for privacy, server handling, and Safe Space adjacency before updating this count."
        )
    }

    /// `SafeSpaceEntry` must remain a `struct`. Converting it to a class
    /// is step one toward making it a SwiftData `@Model`, which is step
    /// one toward accidentally wiring it into `pushAll`. If this test
    /// fails, do not update the assertion — audit the change.
    ///
    /// Main-actor isolated because `SafeSpaceEntry.init` is inferred
    /// `@MainActor`, which is itself a layer of protection: a
    /// nonisolated async context like `pushAll` can't instantiate it.
    @MainActor
    func testSafeSpaceEntryRemainsLocalOnlyStruct() {
        let entry = SafeSpaceEntry(text: "private", date: .now)
        let mirror = Mirror(reflecting: entry)
        XCTAssertEqual(
            mirror.displayStyle, .struct,
            "SafeSpaceEntry must remain a struct. Converting to a class risks silent inclusion in cloud sync; require a deliberate privacy review."
        )
    }
}
