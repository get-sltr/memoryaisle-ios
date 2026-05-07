import Foundation
import SwiftData

/// One-shot meal logger used by the "log without photo" entry points
/// (dashboard recommendation card, meal-plan rows, recipe detail,
/// favorited Mira suggestions). Inserts a `NutritionLog` row stamped
/// with `foodName` so the dashboard meals list can render it. The
/// dashboard counter and macro card both read from `NutritionLog`
/// `@Query`, so the new row shows up on the next render pass.
@MainActor
enum MealLogger {
    /// Persists a meal entry. When `sourceMeal` is provided, the
    /// inserted log carries that Meal's id in `sourceMealId` and the
    /// Meal itself is stamped `consumedAt = .now` — Task 4 atomicity:
    /// adherence state and today's totals never get out of sync.
    /// Returns the inserted log so callers that want to undo or
    /// reference it can. `fiberGrams` defaults to 0 because most
    /// suggestion sources don't carry fiber.
    @discardableResult
    static func log(
        name: String,
        proteinGrams: Double,
        caloriesConsumed: Double,
        fiberGrams: Double = 0,
        sourceMeal: Meal? = nil,
        in context: ModelContext
    ) -> NutritionLog {
        let entry = NutritionLog(
            date: .now,
            proteinGrams: proteinGrams,
            caloriesConsumed: caloriesConsumed,
            waterLiters: 0,
            fiberGrams: fiberGrams,
            foodName: name,
            sourceMealId: sourceMeal?.id
        )
        context.insert(entry)

        // Stamp the planned meal as eaten in the same transaction.
        // Clear any prior skipped/swapped state so the row resolves
        // cleanly to .eaten if the user changes their mind from
        // skipped → eaten via the contextMenu.
        if let sourceMeal {
            sourceMeal.consumedAt = .now
            sourceMeal.skippedAt = nil
            sourceMeal.swappedTo = nil
            sourceMeal.swappedAt = nil
        }

        try? context.save()
        return entry
    }
}
