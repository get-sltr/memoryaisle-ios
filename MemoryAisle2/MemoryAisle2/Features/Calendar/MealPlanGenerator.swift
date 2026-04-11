import Foundation

struct PlannedMeal: Identifiable {
    let id = UUID()
    let time: String
    let name: String
    let protein: Int
    let calories: Int
}

enum MealPlanGenerator {
    static func fetchPlan(
        days: Int,
        profile: UserProfile,
        startDate: Date
    ) async throws -> [Date: [PlannedMeal]] {
        let client = MiraAPIClient()

        let restrictions = profile.dietaryRestrictions
            .map(\.rawValue)
            .joined(separator: ", ")
        let restrictionsLine = restrictions.isEmpty
            ? ""
            : "Dietary restrictions: \(restrictions)."

        let prompt = """
        Generate a \(days)-day meal plan with MAXIMUM VARIETY.

        CRITICAL RULES:
        - Every single meal must be DIFFERENT from every other meal across all \(days) days
        - NO repeated meals, no variations of the same dish
        - 4 meals per day: breakfast (8:30 AM), lunch (12:30 PM), dinner (6:00 PM), snack
        - Protein target: \(profile.proteinTargetGrams)g per day
        - Calorie target: \(profile.calorieTarget) per day
        \(restrictionsLine)

        Respond ONLY in this exact format, one line per meal, no commentary, no markdown:
        DAY|dayNumber|time|name|protein_g|calories

        Example first day:
        DAY|1|8:30 AM|Greek Yogurt Berry Parfait|32|380
        DAY|1|12:30 PM|Grilled Chicken Power Bowl|45|580
        DAY|1|6:00 PM|Baked Salmon with Quinoa|42|540
        DAY|1|Snack|Cottage Cheese with Almonds|24|220

        Continue for all \(days) days. Every meal across every day must be unique.
        """

        let anon = MedicationAnonymizer.anonymize(
            profile: profile,
            cyclePhase: nil,
            symptomState: "unknown",
            proteinConsumed: 0,
            waterConsumed: 0,
            isTrainingDay: false
        )
        let context = MiraAPIClient.MiraContext(
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

        let response = try await client.send(message: prompt, context: context)
        return parseResponse(response, startDate: startDate, dayCount: days)
    }

    private static func parseResponse(
        _ response: String,
        startDate: Date,
        dayCount: Int
    ) -> [Date: [PlannedMeal]] {
        let calendar = Calendar.current
        var plan: [Date: [PlannedMeal]] = [:]

        let lines = response.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.hasPrefix("DAY|") }

        for line in lines {
            let parts = line.components(separatedBy: "|")
            guard parts.count >= 6,
                  let dayNum = Int(parts[1].trimmingCharacters(in: .whitespaces)),
                  dayNum >= 1, dayNum <= dayCount else { continue }

            let time = parts[2].trimmingCharacters(in: .whitespaces)
            let name = parts[3].trimmingCharacters(in: .whitespaces)
            let protein = Int(parts[4].trimmingCharacters(in: .whitespaces)) ?? 0
            let calories = Int(parts[5].trimmingCharacters(in: .whitespaces)) ?? 0

            guard let date = calendar.date(
                byAdding: .day,
                value: dayNum - 1,
                to: calendar.startOfDay(for: startDate)
            ) else { continue }

            let meal = PlannedMeal(
                time: time,
                name: name,
                protein: protein,
                calories: calories
            )
            plan[date, default: []].append(meal)
        }

        return plan
    }
}
