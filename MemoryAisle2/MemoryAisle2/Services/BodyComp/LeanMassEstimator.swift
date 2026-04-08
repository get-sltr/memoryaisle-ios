import Foundation
import SwiftData

struct LeanMassEstimator {

    struct Estimate {
        let leanMassLbs: Double
        let fatMassLbs: Double
        let bodyFatPercent: Double
        let method: EstimationMethod
        let confidence: Confidence
    }

    enum EstimationMethod: String {
        case dexa = "DEXA Scan"
        case smartScale = "Smart Scale"
        case healthKit = "HealthKit"
        case navyFormula = "Navy Formula"
        case bmiBased = "BMI Estimate"
        case defaultEstimate = "Default (25%)"
    }

    enum Confidence: String {
        case high = "High"
        case moderate = "Moderate"
        case low = "Low"
    }

    static func estimate(
        weightLbs: Double,
        heightInches: Int?,
        sex: BiologicalSex?,
        bodyFatPercent: Double? = nil,
        waistInches: Double? = nil,
        neckInches: Double? = nil
    ) -> Estimate {
        if let bf = bodyFatPercent, bf > 0, bf < 60 {
            return fromBodyFat(weight: weightLbs, bf: bf, method: .dexa)
        }

        if let waist = waistInches, let neck = neckInches,
           let height = heightInches, let sex = sex {
            return navyFormula(
                weight: weightLbs, height: height,
                waist: waist, neck: neck, sex: sex
            )
        }

        if let height = heightInches, let sex = sex {
            return bmiEstimate(
                weight: weightLbs, height: height, sex: sex
            )
        }

        return fromBodyFat(
            weight: weightLbs, bf: 25.0, method: .defaultEstimate
        )
    }

    private static func fromBodyFat(
        weight: Double, bf: Double, method: EstimationMethod
    ) -> Estimate {
        let fat = weight * (bf / 100)
        let lean = weight - fat
        let confidence: Confidence = switch method {
        case .dexa, .smartScale: .high
        case .healthKit, .navyFormula: .moderate
        default: .low
        }

        return Estimate(
            leanMassLbs: lean, fatMassLbs: fat,
            bodyFatPercent: bf, method: method,
            confidence: confidence
        )
    }

    private static func navyFormula(
        weight: Double, height: Int,
        waist: Double, neck: Double, sex: BiologicalSex
    ) -> Estimate {
        let heightCm = Double(height) * 2.54
        let waistCm = waist * 2.54
        let neckCm = neck * 2.54

        let bf: Double
        if sex == .male {
            bf = 495
                / (1.0324 - 0.19077 * log10(waistCm - neckCm)
                   + 0.15456 * log10(heightCm))
                - 450
        } else {
            bf = 495
                / (1.29579 - 0.35004 * log10(waistCm + waistCm - neckCm)
                   + 0.22100 * log10(heightCm))
                - 450
        }

        let clampedBf = max(3, min(55, bf))
        return fromBodyFat(
            weight: weight, bf: clampedBf, method: .navyFormula
        )
    }

    private static func bmiEstimate(
        weight: Double, height: Int, sex: BiologicalSex
    ) -> Estimate {
        let heightM = Double(height) * 0.0254
        let weightKg = weight * 0.453592
        let bmi = weightKg / (heightM * heightM)

        let bf: Double
        if sex == .male {
            bf = 1.20 * bmi + 0.23 * 35 - 16.2
        } else {
            bf = 1.20 * bmi + 0.23 * 35 - 5.4
        }

        let clampedBf = max(5, min(55, bf))
        return fromBodyFat(
            weight: weight, bf: clampedBf, method: .bmiBased
        )
    }
}
