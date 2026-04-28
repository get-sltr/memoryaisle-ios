import Foundation
import OSLog
import SwiftData

/// Quota policy for weekly meal-plan generation.
///
/// Policy:
///   - `signup` trigger: always allowed (one per user lifetime). Idempotency
///     comes from the `signupCompletedKey` flag; the orchestrator's in-flight
///     check prevents stacking.
///   - `backfill` trigger: at most one per `backfillCooldown` per user. Avoids
///     hammering Bedrock if the user clears plans manually and reopens the app.
///   - `manual` trigger: Pro users unlimited, free users get 1 per
///     `freeManualCooldown` (matches the existing per-day Mira quota spirit).
@MainActor
struct WeeklyMealUsageGate {

    private let defaults: UserDefaults
    private let logger = Logger(subsystem: "com.memoryaisle.MealGen", category: "Quota")

    /// 7 days minimum between unsolicited backfills.
    let backfillCooldown: TimeInterval = 60 * 60 * 24 * 7
    /// 24 hours between free-tier manual regenerations.
    let freeManualCooldown: TimeInterval = 60 * 60 * 24

    private let signupCompletedKey = "weeklyGen.signupCompletedAt"
    private let lastBackfillKey = "weeklyGen.lastBackfillAt"
    private let lastFreeManualKey = "weeklyGen.lastFreeManualAt"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func canStart(trigger: MealGenerationTrigger, isPro: Bool, in context: ModelContext) -> Bool {
        switch trigger {
        case .signup:
            return defaults.object(forKey: signupCompletedKey) == nil
        case .backfill:
            return cooldownElapsed(forKey: lastBackfillKey, cooldown: backfillCooldown)
        case .manual:
            if isPro { return true }
            return cooldownElapsed(forKey: lastFreeManualKey, cooldown: freeManualCooldown)
        }
    }

    func recordStart(trigger: MealGenerationTrigger, in context: ModelContext) {
        let now = Date()
        switch trigger {
        case .signup:
            defaults.set(now, forKey: signupCompletedKey)
        case .backfill:
            defaults.set(now, forKey: lastBackfillKey)
        case .manual:
            defaults.set(now, forKey: lastFreeManualKey)
        }
        logger.info("Recorded weekly gen start trigger=\(trigger.rawValue, privacy: .public)")
    }

    private func cooldownElapsed(forKey key: String, cooldown: TimeInterval) -> Bool {
        guard let last = defaults.object(forKey: key) as? Date else { return true }
        return Date().timeIntervalSince(last) >= cooldown
    }
}
