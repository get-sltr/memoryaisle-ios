import SwiftData

/// Marker protocol for SwiftData `@Model` types that are allowed to be
/// pushed/pulled by `CloudSyncManager`. Opt-in by design: a model is
/// synced only when it explicitly conforms here. Every model-specific
/// fetch in `CloudSyncManager` flows through a helper constrained to
/// `T: CloudSyncable`, so a non-conforming type cannot reach the
/// network path without a compile error.
///
/// Explicit non-sync zones (these must never conform):
/// - `SafeSpaceEntry` — private journal, FaceID gated, stored only in
///   `Documents/.safespace.json` with `.completeFileProtection`.
///   Local device only. No one is allowed to touch it.
///
/// Do not add conformance to work around a feature. If a new model
/// needs to sync, review the privacy implications first, then extend
/// this protocol and the `CloudSyncableTests` allowlist together.
protocol CloudSyncable: PersistentModel {}

extension UserProfile: CloudSyncable {}
extension NutritionLog: CloudSyncable {}
extension SymptomLog: CloudSyncable {}
extension PantryItem: CloudSyncable {}
