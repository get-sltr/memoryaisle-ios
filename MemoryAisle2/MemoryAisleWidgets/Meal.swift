import Foundation
import SwiftData

@Model
final class Meal {
    var id: String
    var name: String
    var mealType: MealType
    var proteinGrams: Double
    var caloriesTotal: Double
    var carbsGrams: Double
    var fatGrams: Double
    var fiberGrams: Double
    var prepTimeMinutes: Int
    var cookingInstructions: String?
    var ingredients: [String]
    var isNauseaSafe: Bool
    var isHighProtein: Bool
    var createdAt: Date

    @Relationship(inverse: \MealPlan.meals)
    var mealPlan: MealPlan?

    init(
        name: String,
        mealType: MealType,
        proteinGrams: Double,
        caloriesTotal: Double,
        carbsGrams: Double = 0,
        fatGrams: Double = 0,
        fiberGrams: Double = 0,
        prepTimeMinutes: Int = 15,
        cookingInstructions: String? = nil,
        ingredients: [String] = [],
        isNauseaSafe: Bool = false,
        isHighProtein: Bool = false
    ) {
        self.id = UUID().uuidString
        self.name = name
        self.mealType = mealType
        self.proteinGrams = proteinGrams
        self.caloriesTotal = caloriesTotal
        self.carbsGrams = carbsGrams
        self.fatGrams = fatGrams
        self.fiberGrams = fiberGrams
        self.prepTimeMinutes = prepTimeMinutes
        self.cookingInstructions = cookingInstructions
        self.ingredients = ingredients
        self.isNauseaSafe = isNauseaSafe
        self.isHighProtein = isHighProtein
        self.createdAt = Date()
    }
}

enum MealType: String, Codable, CaseIterable {
    case breakfast = "Breakfast"
    case lunch = "Lunch"
    case dinner = "Dinner"
    case snack = "Snack"
    case preWorkout = "Pre-Workout"
    case postWorkout = "Post-Workout"
}
