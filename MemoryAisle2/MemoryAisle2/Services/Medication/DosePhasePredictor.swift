import Foundation

struct DosePhasePredictor {

    struct Prediction {
        let expectedAppetite: AppetiteLevel
        let expectedNausea: NauseaLevel
        let portionAdjustment: Double
        let mealStrategy: String
        let hydrationPriority: HydrationPriority
    }

    enum AppetiteLevel: String {
        case veryLow = "Very Low"
        case low = "Low"
        case moderate = "Moderate"
        case normal = "Normal"
        case increased = "Increased"
    }

    enum NauseaLevel: String {
        case none = "None"
        case mild = "Mild"
        case moderate = "Moderate"
        case severe = "Severe"
    }

    enum HydrationPriority: String {
        case critical = "Critical"
        case high = "High"
        case normal = "Normal"
    }

    static func predict(
        modality: MedicationModality,
        cyclePhase: CyclePhase?,
        weeksOnMedication: Int,
        recentNauseaAvg: Double
    ) -> Prediction {
        let titrationFactor = titrationMultiplier(weeks: weeksOnMedication)
        let historyFactor = min(1.0, recentNauseaAvg / 5.0)

        switch modality {
        case .injectable:
            return predictInjectable(
                phase: cyclePhase ?? .steadyState,
                titration: titrationFactor,
                history: historyFactor
            )
        case .oralWithFasting:
            return predictOralFasting(
                titration: titrationFactor,
                history: historyFactor
            )
        case .oralNoFasting:
            return predictOralNoFasting(
                titration: titrationFactor,
                history: historyFactor
            )
        }
    }

    private static func predictInjectable(
        phase: CyclePhase,
        titration: Double,
        history: Double
    ) -> Prediction {
        let nauseaScore = phase.nauseaRisk * titration
            + history * 0.3

        let appetite: AppetiteLevel = switch nauseaScore {
        case 0.7...: .veryLow
        case 0.5..<0.7: .low
        case 0.3..<0.5: .moderate
        default: .normal
        }

        let nausea: NauseaLevel = switch nauseaScore {
        case 0.7...: .severe
        case 0.5..<0.7: .moderate
        case 0.2..<0.5: .mild
        default: .none
        }

        let portion: Double = switch appetite {
        case .veryLow: 0.5
        case .low: 0.7
        case .moderate: 0.85
        case .normal, .increased: 1.0
        }

        return Prediction(
            expectedAppetite: appetite,
            expectedNausea: nausea,
            portionAdjustment: portion,
            mealStrategy: phase.proteinStrategy,
            hydrationPriority: nauseaScore > 0.5
                ? .critical : .high
        )
    }

    private static func predictOralFasting(
        titration: Double,
        history: Double
    ) -> Prediction {
        let nauseaScore = 0.4 * titration + history * 0.3

        return Prediction(
            expectedAppetite: nauseaScore > 0.5 ? .low : .moderate,
            expectedNausea: nauseaScore > 0.5 ? .moderate : .mild,
            portionAdjustment: nauseaScore > 0.5 ? 0.7 : 0.85,
            mealStrategy: "Protein-first breakfast after fasting window. Small frequent meals throughout the day.",
            hydrationPriority: .high
        )
    }

    private static func predictOralNoFasting(
        titration: Double,
        history: Double
    ) -> Prediction {
        let nauseaScore = 0.25 * titration + history * 0.3

        return Prediction(
            expectedAppetite: nauseaScore > 0.4 ? .low : .moderate,
            expectedNausea: nauseaScore > 0.4 ? .mild : .none,
            portionAdjustment: nauseaScore > 0.4 ? 0.8 : 0.95,
            mealStrategy: "Standard protein-first meals. Take pill with your largest meal for best absorption.",
            hydrationPriority: .normal
        )
    }

    private static func titrationMultiplier(weeks: Int) -> Double {
        switch weeks {
        case 1...4: 1.0
        case 5...8: 0.8
        case 9...12: 0.6
        default: 0.4
        }
    }
}
