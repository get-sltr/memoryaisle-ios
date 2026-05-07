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
    /// Persists a meal entry. Returns the inserted log so callers that
    /// want to undo or reference it can. `fiberGrams` defaults to 0
    /// because most suggestion sources don't carry fiber.
    @discardableResult
    static func log(
        name: String,
        proteinGrams: Double,
        caloriesConsumed: Double,
        fiberGrams: Double = 0,
        in context: ModelContext
    ) -> NutritionLog {
        let entry = NutritionLog(
            date: .now,
            proteinGrams: proteinGrams,
            caloriesConsumed: caloriesConsumed,
            waterLiters: 0,
            fiberGrams: fiberGrams,
            foodName: name
        )
        context.insert(entry)
        try? context.save()
        return entry
    }
}
