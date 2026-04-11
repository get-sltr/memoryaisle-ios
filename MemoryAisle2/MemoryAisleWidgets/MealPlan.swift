import Foundation
import SwiftData

@Model
final class MealPlan {
    var id: String
    var date: Date
    var productMode: ProductMode
    var totalProteinGrams: Double
    var totalCalories: Double
    var generatedAt: Date
    var isActive: Bool

    @Relationship(deleteRule: .cascade)
    var meals: [Meal]

    init(
        date: Date = .now,
        productMode: ProductMode = .everyday,
        meals: [Meal] = []
    ) {
        self.id = UUID().uuidString
        self.date = date
        self.productMode = productMode
        self.meals = meals
        self.totalProteinGrams = meals.reduce(0) { $0 + $1.proteinGrams }
        self.totalCalories = meals.reduce(0) { $0 + $1.caloriesTotal }
        self.generatedAt = Date()
        self.isActive = true
    }

    func recalculateTotals() {
        totalProteinGrams = meals.reduce(0) { $0 + $1.proteinGrams }
        totalCalories = meals.reduce(0) { $0 + $1.caloriesTotal }
    }
}
