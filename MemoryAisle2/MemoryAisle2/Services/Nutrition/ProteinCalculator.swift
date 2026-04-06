import Foundation

struct ProteinCalculator {

    struct Input {
        let bodyWeightLbs: Double
        let bodyFatPercentage: Double?
        let trainingLevel: TrainingLevel
        let cyclePhase: CyclePhase?
    }

    struct Result {
        let dailyTargetGrams: Int
        let perMealTargetGrams: Int
        let leanMassLbs: Double
        let gramsPerLbLeanMass: Double
    }

    static func calculate(input: Input) -> Result {
        let leanMass: Double
        if let bf = input.bodyFatPercentage {
            leanMass = input.bodyWeightLbs * (1 - bf / 100)
        } else {
            // Estimate: assume 25% body fat if unknown
            leanMass = input.bodyWeightLbs * 0.75
        }

        let gramsPerLb: Double = switch input.trainingLevel {
        case .lifts: 1.2
        case .cardio: 1.0
        case .sometimes: 0.9
        case .none: 0.8
        }

        var dailyTarget = leanMass * gramsPerLb

        // Adjust for cycle phase
        if let phase = input.cyclePhase {
            switch phase {
            case .injectionDay, .peakSuppression:
                // Don't reduce target, but flag difficulty
                break
            case .appetiteReturn, .preInjection:
                // Increase slightly to compensate for low days
                dailyTarget *= 1.05
            case .steadyState:
                break
            }
        }

        let target = Int(dailyTarget.rounded())
        let mealsPerDay = 4
        let perMeal = target / mealsPerDay

        return Result(
            dailyTargetGrams: target,
            perMealTargetGrams: perMeal,
            leanMassLbs: leanMass,
            gramsPerLbLeanMass: gramsPerLb
        )
    }
}
