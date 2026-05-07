import Foundation
import SwiftData

@Model
final class Meal: Identifiable {
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

    /// Adherence: when the user logged this planned meal as eaten.
    /// Nil means not yet eaten / no signal. Set by MealLogger when the
    /// user taps "Mark as eaten" or logs from the row's contextMenu —
    /// the same call also writes a NutritionLog row with sourceMealId
    /// pointing back here, so today's totals and the planned-vs-eaten
    /// reconciliation stay in sync.
    var consumedAt: Date?

    /// Adherence: when the user marked this planned meal as skipped.
    /// Nil means not skipped (which is different from "not yet
    /// decided" — the UI treats both as "open"). Mutually exclusive
    /// with `consumedAt` in normal use; a row can be flipped from
    /// skipped → eaten by tapping again, in which case skippedAt is
    /// cleared. Task 5 reads (consumedAt, skippedAt, swappedAt) to
    /// build the adherence summary that goes into the meal-plan prompt.
    var skippedAt: Date?

    /// Adherence: free-form name of what the user ate instead of the
    /// planned meal ("Chipotle bowl", "Pizza"). Nil means no swap.
    /// Quantity-aware comparison is out of scope — Mira gets the raw
    /// string and infers patterns from the swap log.
    var swappedTo: String?

    /// Adherence: when the swap was logged. Distinct from `swappedTo`
    /// so Task 5 can build a temporally-ordered swap log (e.g.,
    /// "swapped 3 dinners last week, all on Tue/Thu") without inferring
    /// timestamps from the parent MealPlan's date.
    var swappedAt: Date?

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

    /// Resolved adherence state for the row. Mutually exclusive: one of
    /// `.eaten`, `.skipped`, `.swapped`, or `.open`. Used by the row
    /// view to pick the right visual treatment without re-deriving
    /// from three nullable fields each render.
    var adherenceState: AdherenceState {
        if let consumedAt {
            return .eaten(at: consumedAt)
        }
        if let swappedAt, let swappedTo {
            return .swapped(to: swappedTo, at: swappedAt)
        }
        if let skippedAt {
            return .skipped(at: skippedAt)
        }
        return .open
    }
}

enum AdherenceState: Equatable, Sendable {
    case open
    case eaten(at: Date)
    case skipped(at: Date)
    case swapped(to: String, at: Date)
}

enum MealType: String, Codable, CaseIterable {
    case breakfast = "Breakfast"
    case lunch = "Lunch"
    case dinner = "Dinner"
    case snack = "Snack"
    case preWorkout = "Pre-Workout"
    case postWorkout = "Post-Workout"
}
