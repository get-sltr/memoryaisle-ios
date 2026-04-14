import Foundation

/// Returns [] in v1. Structural placeholder so the Reflection "Meals"
/// filter chip is wired and ready to populate when Meal gains a photoData
/// field, an "I ate this" flag, or saved-recipe tracking from the Mira
/// recipe browser. Kept as a real type so the service layer doesn't need
/// to special-case the filter and so the empty list is a forward-compat
/// guarantee, not a placecard.
struct MealMomentTransformer: MomentTransformer {

    func moments(from records: ReflectionSourceRecords) throws -> [ReflectionMoment] {
        // Returns [] until Meal model gains photoData, wasEaten flag, or
        // saved-recipe linking. When those fields exist, this body queries
        // them and emits a moment per saved/cooked meal.
        []
    }
}
