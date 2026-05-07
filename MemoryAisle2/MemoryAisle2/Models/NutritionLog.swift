import Foundation
import SwiftData

@Model
final class NutritionLog {
    var date: Date
    var proteinGrams: Double
    var caloriesConsumed: Double
    var waterLiters: Double
    var fiberGrams: Double
    // Optional so legacy rows and water-only logs migrate cleanly with
    // SwiftData lightweight migration. A non-nil foodName marks this row
    // as a real meal entry that Reflection should turn into a moment.
    var foodName: String?
    var photoData: Data?

    /// Pointer back to the planned `Meal.id` this log was created from
    /// when the user logged via "Mark as eaten" on a meal-plan row.
    /// Nil for free-form logs (photo, scan, "Ate something else", Mira
    /// chat tool). Optional so legacy rows decode cleanly under
    /// lightweight migration. Task 5's adherence reconciliation reads
    /// this to answer "of yesterday's planned meals, what was actually
    /// eaten?" — a question we can't answer from `foodName` matching
    /// alone (users log "Eggs" both as a planned breakfast and as a
    /// free-form snack).
    var sourceMealId: String?

    init(
        date: Date = .now,
        proteinGrams: Double = 0,
        caloriesConsumed: Double = 0,
        waterLiters: Double = 0,
        fiberGrams: Double = 0,
        foodName: String? = nil,
        photoData: Data? = nil,
        sourceMealId: String? = nil
    ) {
        self.date = date
        self.proteinGrams = proteinGrams
        self.caloriesConsumed = caloriesConsumed
        self.waterLiters = waterLiters
        self.fiberGrams = fiberGrams
        self.foodName = foodName
        self.photoData = photoData
        self.sourceMealId = sourceMealId
    }
}
