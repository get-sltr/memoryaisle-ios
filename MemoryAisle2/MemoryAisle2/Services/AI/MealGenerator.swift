import Foundation
import SwiftData

@MainActor
final class MealGenerator {
    private let apiClient = MiraAPIClient()

    func generateDailyPlan(
        profile: UserProfile,
        cyclePhase: CyclePhase?,
        giTriggers: [String],
        pantryItems: [PantryItem],
        isTrainingDay: Bool,
        context: ModelContext
    ) async throws -> MealPlan {
        let systemPrompt = MiraEngine.buildSystemPrompt(
            profile: profile,
            cyclePhase: cyclePhase,
            giTriggers: giTriggers,
            pantryItems: pantryItems
        )

        let mealRequest = buildMealRequest(
            profile: profile,
            cyclePhase: cyclePhase,
            isTrainingDay: isTrainingDay,
            pantry: pantryItems
        )

        let anon = MedicationAnonymizer.anonymize(
            profile: profile,
            cyclePhase: cyclePhase,
            symptomState: "unknown",
            proteinConsumed: 0,
            waterConsumed: 0,
            isTrainingDay: isTrainingDay
        )
        let miraContext = MiraAPIClient.MiraContext(
            medicationClass: anon.medicationClass,
            doseTier: anon.doseTier,
            daysSinceDose: anon.daysSinceDose,
            phase: anon.phase,
            symptomState: anon.symptomState,
            mode: anon.productMode,
            proteinTarget: anon.proteinTargetGrams,
            proteinToday: 0,
            waterToday: 0,
            trainingLevel: anon.trainingLevel,
            trainingToday: anon.trainingToday,
            calorieTarget: anon.calorieTarget,
            dietaryRestrictions: anon.dietaryRestrictions
        )

        let response = try await apiClient.send(
            message: "\(systemPrompt)\n\n\(mealRequest)",
            context: miraContext
        )

        let meals = parseMeals(from: response, profile: profile)

        let plan = MealPlan(
            date: .now,
            productMode: profile.productMode,
            meals: meals
        )
        context.insert(plan)

        for meal in meals {
            context.insert(meal)
        }

        return plan
    }

    private func buildMealRequest(
        profile: UserProfile,
        cyclePhase: CyclePhase?,
        isTrainingDay: Bool,
        pantry: [PantryItem]
    ) -> String {
        let mealCount = isTrainingDay ? 5 : 4
        let restrictions = profile.dietaryRestrictions
            .map(\.rawValue).joined(separator: ", ")

        var request = """
        Generate \(mealCount) meals for today. \
        Protein target: \(profile.proteinTargetGrams)g total. \
        Calorie target: \(profile.calorieTarget) total.
        """

        if isTrainingDay {
            request += " Include pre-workout and post-workout meals."
        }

        if let phase = cyclePhase {
            request += " Cycle phase: \(phase.rawValue). \(phase.proteinStrategy)"
        }

        if !restrictions.isEmpty {
            request += " Dietary restrictions: \(restrictions)."
        }

        if !pantry.isEmpty {
            let available = pantry.prefix(15)
                .map(\.name).joined(separator: ", ")
            request += " Available in pantry: \(available)."
        }

        request += """

        For each meal respond in this exact format:
        MEAL|type|name|protein_g|calories|carbs_g|fat_g|fiber_g|\
        prep_minutes|nausea_safe|ingredients(comma-separated)|\
        cooking_instructions
        Types: breakfast, lunch, dinner, snack, pre-workout, post-workout
        """

        return request
    }

    func parseMeals(
        from response: String,
        profile: UserProfile
    ) -> [Meal] {
        let lines = response.components(separatedBy: "\n")
            .filter { $0.hasPrefix("MEAL|") }

        var meals: [Meal] = []

        for line in lines {
            let parts = line.components(separatedBy: "|")
            guard parts.count >= 10 else { continue }

            let mealType = parseMealType(parts[1].trimmingCharacters(
                in: .whitespaces
            ))
            let name = parts[2].trimmingCharacters(in: .whitespaces)
            let protein = Double(parts[3].trimmingCharacters(
                in: .whitespaces
            )) ?? 0
            let calories = Double(parts[4].trimmingCharacters(
                in: .whitespaces
            )) ?? 0
            let carbs = Double(parts[5].trimmingCharacters(
                in: .whitespaces
            )) ?? 0
            let fat = Double(parts[6].trimmingCharacters(
                in: .whitespaces
            )) ?? 0
            let fiber = Double(parts[7].trimmingCharacters(
                in: .whitespaces
            )) ?? 0
            let prep = Int(parts[8].trimmingCharacters(
                in: .whitespaces
            )) ?? 15
            let nauseaSafe = parts[9].trimmingCharacters(
                in: .whitespaces
            ).lowercased() == "true"

            let ingredients: [String]
            if parts.count > 10 {
                ingredients = parts[10].components(separatedBy: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
            } else {
                ingredients = []
            }

            let instructions: String?
            if parts.count > 11 {
                instructions = parts[11].trimmingCharacters(
                    in: .whitespaces
                )
            } else {
                instructions = nil
            }

            let meal = Meal(
                name: name,
                mealType: mealType,
                proteinGrams: protein,
                caloriesTotal: calories,
                carbsGrams: carbs,
                fatGrams: fat,
                fiberGrams: fiber,
                prepTimeMinutes: prep,
                cookingInstructions: instructions,
                ingredients: ingredients,
                isNauseaSafe: nauseaSafe,
                isHighProtein: protein >= 25
            )
            meals.append(meal)
        }

        if meals.isEmpty {
            return fallbackMeals(profile: profile)
        }

        return meals
    }

    private func parseMealType(_ raw: String) -> MealType {
        switch raw.lowercased() {
        case "breakfast": .breakfast
        case "lunch": .lunch
        case "dinner": .dinner
        case "snack": .snack
        case "pre-workout", "preworkout": .preWorkout
        case "post-workout", "postworkout": .postWorkout
        default: .snack
        }
    }

    private func fallbackMeals(profile: UserProfile) -> [Meal] {
        let perMeal = Double(profile.proteinTargetGrams) / 4.0
        let calPerMeal = Double(profile.calorieTarget) / 4.0

        return [
            Meal(
                name: "Protein-packed breakfast",
                mealType: .breakfast,
                proteinGrams: perMeal * 1.1,
                caloriesTotal: calPerMeal,
                isNauseaSafe: true,
                isHighProtein: true
            ),
            Meal(
                name: "Lean lunch bowl",
                mealType: .lunch,
                proteinGrams: perMeal * 1.1,
                caloriesTotal: calPerMeal * 1.1,
                isHighProtein: true
            ),
            Meal(
                name: "Protein snack",
                mealType: .snack,
                proteinGrams: perMeal * 0.6,
                caloriesTotal: calPerMeal * 0.5,
                isNauseaSafe: true,
                isHighProtein: true
            ),
            Meal(
                name: "Balanced dinner",
                mealType: .dinner,
                proteinGrams: perMeal * 1.2,
                caloriesTotal: calPerMeal * 1.4,
                isHighProtein: true
            ),
        ]
    }
}
