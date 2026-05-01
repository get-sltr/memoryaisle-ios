import Foundation

/// Computes the user's daily protein target from lean body mass and a
/// training multiplier, with safety clamps on every input. Wrong
/// targets directly drive wrong user guidance, so the calculator:
///
/// 1. Clamps `bodyWeightLbs` to `>= 0`. Negative or zero weight falls
///    through to the safety floor.
/// 2. Clamps `bodyFatPercentage` to the plausible range (0 ... 90).
///    Values outside that range are almost always data-entry errors.
/// 3. Enforces `minimumDailyTargetGrams` as a hard floor on the output
///    so a user with partial profile data never gets a 0g target.
struct ProteinCalculator {

    /// Minimum daily protein target the calculator will ever return,
    /// regardless of input. Calibrated as a conservative floor that
    /// still produces useful guidance for small or under-configured
    /// users without under-dosing muscle preservation.
    static let minimumDailyTargetGrams: Int = 60

    /// Safe body-fat range. Anything outside this is treated as a
    /// data-entry error and clamped. Upper bound is 90 rather than 100
    /// so lean mass never collapses to zero from a plausible input.
    private static let bodyFatClampRange: ClosedRange<Double> = 0 ... 90

    /// Default body-fat estimate when the user hasn't entered one yet.
    /// Chosen to be conservative (not too low) so we don't inflate the
    /// protein target in the absence of real data.
    private static let defaultBodyFatPercentage: Double = 25

    private static let mealsPerDay: Int = 4

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
        let safeWeight = max(0, input.bodyWeightLbs)
        let gramsPerLb = gramsPerLb(for: input.trainingLevel)

        let bfRaw = input.bodyFatPercentage ?? defaultBodyFatPercentage
        let bf = bfRaw.clamped(to: bodyFatClampRange)
        let leanMass = max(0, safeWeight * (1 - bf / 100))

        var dailyTarget = leanMass * gramsPerLb

        if let phase = input.cyclePhase {
            switch phase {
            case .appetiteReturn, .preInjection:
                // Compensate for the low-appetite days users just
                // came off of; modest 5% bump.
                dailyTarget *= 1.05
            case .injectionDay, .peakSuppression, .steadyState:
                break
            }
        }

        let rawTarget = Int(dailyTarget.rounded())
        let clampedTarget = max(minimumDailyTargetGrams, rawTarget)
        let perMeal = max(1, clampedTarget / mealsPerDay)

        return Result(
            dailyTargetGrams: clampedTarget,
            perMealTargetGrams: perMeal,
            leanMassLbs: leanMass,
            gramsPerLbLeanMass: gramsPerLb
        )
    }

    private static func gramsPerLb(for level: TrainingLevel) -> Double {
        switch level {
        case .lifts:         1.2
        case .cardio:        1.0
        case .sometimes:     0.9
        case .none:          0.8
        case .nutritionOnly: 0.8
        }
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
