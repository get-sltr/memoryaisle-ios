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
        /// Task 5: when ON, MealGenerator appends an AdherenceContext
        /// fragment (last 7 days hit/miss/swap log) to the system prompt
        /// so Mira can adapt the next plan to what the user actually ate.
        /// Ships OFF by default — adherence context changes the prompt
        /// shape and adds tokens, so we want a kill switch we can flip
        /// from a debug build (or a future RemoteFlagSync) without
        /// redeploying the Lambda or shipping a new IPA.
        case adherenceContext = "adherence_context_enabled"
    }

    private static let defaultValues: [Flag: Bool] = [
        // weeklyMealPlan + weeklyMealBackfill ship ON. adherenceContext
        // ships OFF until we've validated the prompt language doesn't
        // confuse Mira on accounts with sparse adherence data.
        .weeklyMealPlan: true,
        .weeklyMealBackfill: true,
        .adherenceContext: false
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
