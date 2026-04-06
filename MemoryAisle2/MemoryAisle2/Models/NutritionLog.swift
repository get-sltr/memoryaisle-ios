import Foundation
import SwiftData

@Model
final class NutritionLog {
    var date: Date
    var proteinGrams: Double
    var caloriesConsumed: Double
    var waterLiters: Double
    var fiberGrams: Double

    init(
        date: Date = .now,
        proteinGrams: Double = 0,
        caloriesConsumed: Double = 0,
        waterLiters: Double = 0,
        fiberGrams: Double = 0
    ) {
        self.date = date
        self.proteinGrams = proteinGrams
        self.caloriesConsumed = caloriesConsumed
        self.waterLiters = waterLiters
        self.fiberGrams = fiberGrams
    }
}
