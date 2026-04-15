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

    init(
        date: Date = .now,
        proteinGrams: Double = 0,
        caloriesConsumed: Double = 0,
        waterLiters: Double = 0,
        fiberGrams: Double = 0,
        foodName: String? = nil,
        photoData: Data? = nil
    ) {
        self.date = date
        self.proteinGrams = proteinGrams
        self.caloriesConsumed = caloriesConsumed
        self.waterLiters = waterLiters
        self.fiberGrams = fiberGrams
        self.foodName = foodName
        self.photoData = photoData
    }
}
