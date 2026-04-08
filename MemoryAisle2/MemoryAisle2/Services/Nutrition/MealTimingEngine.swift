import Foundation

struct MealTimingEngine {

    struct MealSchedule {
        let meals: [ScheduledMeal]
        let nextMealTime: Date?
        let nextMealType: MealType?
    }

    struct ScheduledMeal {
        let type: MealType
        let time: Date
        let proteinTarget: Double
        let calorieTarget: Double
        let notes: String?
    }

    static func buildSchedule(
        modality: MedicationModality,
        pillTime: Date?,
        injectionDay: Int?,
        cyclePhase: CyclePhase?,
        isTrainingDay: Bool,
        proteinTarget: Int,
        calorieTarget: Int
    ) -> MealSchedule {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        var meals: [ScheduledMeal] = []
        let proteinPerMeal: Double
        let caloriesPerMeal: Double

        if isTrainingDay {
            proteinPerMeal = Double(proteinTarget) / 5.0
            caloriesPerMeal = Double(calorieTarget) / 5.0
            meals = buildTrainingDayMeals(
                base: today,
                protein: proteinPerMeal,
                calories: caloriesPerMeal,
                calendar: calendar
            )
        } else {
            proteinPerMeal = Double(proteinTarget) / 4.0
            caloriesPerMeal = Double(calorieTarget) / 4.0
            meals = buildStandardMeals(
                base: today,
                protein: proteinPerMeal,
                calories: caloriesPerMeal,
                calendar: calendar
            )
        }

        meals = adjustForModality(
            meals: meals,
            modality: modality,
            pillTime: pillTime,
            cyclePhase: cyclePhase,
            calendar: calendar,
            base: today
        )

        let now = Date.now
        let nextMeal = meals.first { $0.time > now }

        return MealSchedule(
            meals: meals,
            nextMealTime: nextMeal?.time,
            nextMealType: nextMeal?.type
        )
    }

    private static func buildStandardMeals(
        base: Date,
        protein: Double,
        calories: Double,
        calendar: Calendar
    ) -> [ScheduledMeal] {
        [
            ScheduledMeal(
                type: .breakfast,
                time: calendar.date(
                    bySettingHour: 8, minute: 0, second: 0, of: base
                ) ?? base,
                proteinTarget: protein * 1.1,
                calorieTarget: calories,
                notes: nil
            ),
            ScheduledMeal(
                type: .lunch,
                time: calendar.date(
                    bySettingHour: 12, minute: 30, second: 0, of: base
                ) ?? base,
                proteinTarget: protein * 1.1,
                calorieTarget: calories * 1.1,
                notes: nil
            ),
            ScheduledMeal(
                type: .snack,
                time: calendar.date(
                    bySettingHour: 15, minute: 30, second: 0, of: base
                ) ?? base,
                proteinTarget: protein * 0.6,
                calorieTarget: calories * 0.5,
                notes: "Protein-dense snack to close deficit"
            ),
            ScheduledMeal(
                type: .dinner,
                time: calendar.date(
                    bySettingHour: 19, minute: 0, second: 0, of: base
                ) ?? base,
                proteinTarget: protein * 1.2,
                calorieTarget: calories * 1.4,
                notes: nil
            ),
        ]
    }

    private static func buildTrainingDayMeals(
        base: Date,
        protein: Double,
        calories: Double,
        calendar: Calendar
    ) -> [ScheduledMeal] {
        var meals = buildStandardMeals(
            base: base, protein: protein,
            calories: calories, calendar: calendar
        )

        meals.insert(
            ScheduledMeal(
                type: .preWorkout,
                time: calendar.date(
                    bySettingHour: 16, minute: 0, second: 0, of: base
                ) ?? base,
                proteinTarget: protein * 0.5,
                calorieTarget: calories * 0.6,
                notes: "Fast carbs + moderate protein 60 min before training"
            ),
            at: 3
        )

        return meals
    }

    private static func adjustForModality(
        meals: [ScheduledMeal],
        modality: MedicationModality,
        pillTime: Date?,
        cyclePhase: CyclePhase?,
        calendar: Calendar,
        base: Date
    ) -> [ScheduledMeal] {
        guard modality == .oralWithFasting, let pill = pillTime else {
            return meals
        }

        let pillHour = calendar.component(.hour, from: pill)
        let earliestEat = calendar.date(
            bySettingHour: pillHour, minute: 30, second: 0, of: base
        ) ?? base

        return meals.map { meal in
            if meal.type == .breakfast && meal.time < earliestEat {
                return ScheduledMeal(
                    type: meal.type,
                    time: earliestEat,
                    proteinTarget: meal.proteinTarget,
                    calorieTarget: meal.calorieTarget,
                    notes: "Delayed for fasting window. Protein-first."
                )
            }
            return meal
        }
    }
}
