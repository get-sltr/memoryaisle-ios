import Foundation

struct MedicationAnonymizer {

    struct AnonymizedContext: Codable, Sendable {
        let medicationClass: String
        let doseTier: String
        let daysSinceDose: Int?
        let phase: String?
        let symptomState: String
        let proteinTargetGrams: Int
        let proteinConsumedGrams: Int
        let waterConsumedLiters: Double
        let trainingToday: Bool
        let trainingLevel: String
        let dietaryRestrictions: [String]
        let productMode: String
        let fiberTargetGrams: Int
        let calorieTarget: Int
    }

    static func anonymize(
        profile: UserProfile,
        cyclePhase: CyclePhase?,
        symptomState: String,
        proteinConsumed: Int,
        waterConsumed: Double,
        isTrainingDay: Bool
    ) -> AnonymizedContext {
        AnonymizedContext(
            medicationClass: anonymizeMedClass(profile.medication),
            doseTier: anonymizeDoseTier(profile.doseAmount),
            daysSinceDose: daysSinceDose(profile),
            phase: cyclePhase?.anonymizedName,
            symptomState: symptomState,
            proteinTargetGrams: profile.proteinTargetGrams,
            proteinConsumedGrams: proteinConsumed,
            waterConsumedLiters: waterConsumed,
            trainingToday: isTrainingDay,
            trainingLevel: anonymizeTraining(profile.trainingLevel),
            dietaryRestrictions: profile.dietaryRestrictions
                .map(\.rawValue),
            productMode: profile.productMode.rawValue,
            fiberTargetGrams: profile.fiberTargetGrams,
            calorieTarget: profile.calorieTarget
        )
    }

    private static func anonymizeMedClass(
        _ medication: Medication?
    ) -> String {
        guard let med = medication else { return "none" }
        switch med {
        case .ozempic, .wegovy, .wegovyPill, .rybelsus,
             .compoundedSemaglutide:
            return "glp1_agonist_semaglutide_class"
        case .mounjaro, .zepbound, .compoundedTirzepatide:
            return "glp1_gip_dual_agonist"
        case .foundayo:
            return "glp1_agonist_oral_nonfasting"
        case .other:
            return "glp1_agonist_unspecified"
        }
    }

    private static func anonymizeDoseTier(
        _ doseAmount: String?
    ) -> String {
        guard let dose = doseAmount?.lowercased() else {
            return "unknown"
        }

        let numericValue = extractNumeric(from: dose)

        if dose.contains("mg") {
            return switch numericValue {
            case ..<5: "low"
            case 5..<10: "medium"
            case 10..<20: "high"
            default: "very_high"
            }
        }

        if dose.contains("ml") || dose.contains("unit") {
            return switch numericValue {
            case ..<0.5: "low"
            case 0.5..<1.0: "medium"
            case 1.0..<2.0: "high"
            default: "very_high"
            }
        }

        return "unspecified"
    }

    private static func extractNumeric(from text: String) -> Double {
        let pattern = "[0-9]+\\.?[0-9]*"
        guard let range = text.range(
            of: pattern, options: .regularExpression
        ) else { return 0 }
        return Double(text[range]) ?? 0
    }

    private static func daysSinceDose(
        _ profile: UserProfile
    ) -> Int? {
        guard profile.medicationModality == .injectable,
              let injDay = profile.injectionDay else {
            return nil
        }
        return InjectionCycleEngine.daysSince(injectionDay: injDay)
    }

    private static func anonymizeTraining(
        _ level: TrainingLevel
    ) -> String {
        switch level {
        case .lifts: "strength_training"
        case .cardio: "cardio_focused"
        case .sometimes: "occasional"
        case .none: "sedentary"
        }
    }
}

// MARK: - CyclePhase extension for anonymization

extension CyclePhase {
    var anonymizedName: String {
        switch self {
        case .injectionDay: "dose_day"
        case .peakSuppression: "appetite_suppression"
        case .steadyState: "steady"
        case .appetiteReturn: "appetite_returning"
        case .preInjection: "pre_dose"
        }
    }
}
