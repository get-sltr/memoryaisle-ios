import Foundation
import OSLog

/// Local feature-flag registry. UserDefaults-backed so flags persist across
/// launches; the public surface lets a remote-config layer override values
/// in the future without changing call sites.
///
/// Flags default OFF for staged rollout. Flip on by:
///   - `FeatureFlags.shared.set(.weeklyMealPlan, true)` from a debug build
///   - User defaults key `ff_<rawValue>` in CI/test fixtures
///   - A future `RemoteFlagSync` that pulls from the server
@MainActor
final class FeatureFlags {

    static let shared = FeatureFlags()

    private let defaults: UserDefaults
    private let logger = Logger(subsystem: "com.memoryaisle.System", category: "FeatureFlags")

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    enum Flag: String, CaseIterable, Sendable {
        case weeklyMealPlan = "weekly_meal_plan_enabled"
        case weeklyMealBackfill = "weekly_meal_backfill_enabled"
    }

    private static let defaultValues: [Flag: Bool] = [
        // Default OFF until medical/legal review of the weekly plan surface
        // completes (see docs/weekly-meal-plan-review.md). Flip via the
        // setter — `FeatureFlags.shared.set(.weeklyMealPlan, true)` — once
        // the three reviewer sign-offs in that doc are recorded.
        .weeklyMealPlan: false,
        // Default OFF for the same reason; backfill activates after the
        // primary flag is enabled and stable for current signups.
        .weeklyMealBackfill: false
    ]

    func isEnabled(_ flag: Flag) -> Bool {
        let key = key(for: flag)
        if defaults.object(forKey: key) == nil {
            return Self.defaultValues[flag] ?? false
        }
        return defaults.bool(forKey: key)
    }

    func set(_ flag: Flag, _ value: Bool) {
        defaults.set(value, forKey: key(for: flag))
        logger.info("Flag \(flag.rawValue, privacy: .public) set to \(value, privacy: .public)")
    }

    func reset(_ flag: Flag) {
        defaults.removeObject(forKey: key(for: flag))
    }

    private func key(for flag: Flag) -> String {
        "ff_\(flag.rawValue)"
    }

    // MARK: - Convenience accessors used by call sites

    var weeklyMealPlanEnabled: Bool { isEnabled(.weeklyMealPlan) }
    var weeklyMealBackfillEnabled: Bool { isEnabled(.weeklyMealBackfill) }
}
