import Foundation
@testable import MemoryAisle2

/// Builders for the SwiftData models the Reflection transformers read from.
/// Used across all transformer tests so each test file doesn't repeat date
/// math or default values. Each helper takes a daysAgo offset so tests can
/// construct chronological scenarios cleanly.
enum ReflectionTestFixtures {

    static func bodyComp(
        daysAgo: Int = 0,
        weightLbs: Double = 180,
        leanMass: Double? = nil,
        bodyFat: Double? = nil,
        photo: Data? = nil,
        source: BodyCompSource = .manual
    ) -> BodyComposition {
        BodyComposition(
            date: dateOffset(daysAgo),
            weightLbs: weightLbs,
            bodyFatPercent: bodyFat,
            leanMassLbs: leanMass,
            source: source,
            photoData: photo
        )
    }

    static func session(
        daysAgo: Int = 0,
        type: WorkoutType = .weights,
        duration: Int = 45,
        intensity: WorkoutIntensity = .moderate,
        muscles: [MuscleGroup] = [.legs]
    ) -> TrainingSession {
        TrainingSession(
            date: dateOffset(daysAgo),
            type: type,
            durationMinutes: duration,
            intensity: intensity,
            muscleGroups: muscles
        )
    }

    static func nutrition(
        daysAgo: Int = 0,
        protein: Double = 120,
        calories: Double = 1800,
        water: Double = 2.0,
        fiber: Double = 25
    ) -> NutritionLog {
        NutritionLog(
            date: dateOffset(daysAgo),
            proteinGrams: protein,
            caloriesConsumed: calories,
            waterLiters: water,
            fiberGrams: fiber
        )
    }

    static func symptom(
        daysAgo: Int = 0,
        nausea: Int = 0,
        appetite: Int = 3,
        energy: Int = 3
    ) -> SymptomLog {
        SymptomLog(
            date: dateOffset(daysAgo),
            nauseaLevel: nausea,
            appetiteLevel: appetite,
            energyLevel: energy
        )
    }

    static func profile(
        weightLbs: Double = 180,
        goalWeightLbs: Double = 165,
        proteinTarget: Int = 140
    ) -> UserProfile {
        let u = UserProfile(
            medication: nil,
            medicationModality: nil,
            productMode: .everyday,
            proteinTargetGrams: proteinTarget
        )
        u.weightLbs = weightLbs
        u.goalWeightLbs = goalWeightLbs
        return u
    }

    private static func dateOffset(_ days: Int) -> Date {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        return cal.date(byAdding: .day, value: -days, to: today) ?? today
    }
}
