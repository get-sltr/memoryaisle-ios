import Foundation
import SwiftData

struct TaperManager {

    struct TaperPlan {
        let currentDose: String
        let previousDose: String?
        let weeksOnCurrentDose: Int
        let phase: TaperPhase
        let calorieAdjustment: Double
        let proteinAdjustment: Double
        let guidance: String
    }

    enum TaperPhase: String {
        case preTaper = "Pre-Taper"
        case activeTaper = "Active Taper"
        case doseReduction = "Dose Reduction"
        case discontinuing = "Discontinuing"
        case postMedication = "Post-Medication"
    }

    static func evaluate(profile: MedicationProfile) -> TaperPlan {
        guard profile.isOnTaper else {
            return TaperPlan(
                currentDose: profile.doseAmount,
                previousDose: nil,
                weeksOnCurrentDose: profile.weeksOnMedication,
                phase: .preTaper,
                calorieAdjustment: 1.0,
                proteinAdjustment: 1.0,
                guidance: "Stable dose. Continue current nutrition plan."
            )
        }

        let weeksSinceTaper = weeksSinceTaperStart(profile)
        let phase = determineTaperPhase(
            weeksSinceTaper: weeksSinceTaper,
            currentDose: profile.doseAmount
        )

        return TaperPlan(
            currentDose: profile.doseAmount,
            previousDose: profile.previousDose,
            weeksOnCurrentDose: weeksSinceTaper,
            phase: phase,
            calorieAdjustment: calorieMultiplier(phase: phase),
            proteinAdjustment: proteinMultiplier(phase: phase),
            guidance: taperGuidance(phase: phase)
        )
    }

    static func startTaper(
        profile: MedicationProfile,
        newDose: String,
        context: ModelContext
    ) {
        profile.previousDose = profile.doseAmount
        profile.doseAmount = newDose
        profile.isOnTaper = true
        profile.taperStartDate = .now
    }

    private static func weeksSinceTaperStart(
        _ profile: MedicationProfile
    ) -> Int {
        guard let start = profile.taperStartDate else { return 0 }
        let days = Calendar.current.dateComponents(
            [.day], from: start, to: .now
        ).day ?? 0
        return max(0, days / 7)
    }

    private static func determineTaperPhase(
        weeksSinceTaper: Int,
        currentDose: String
    ) -> TaperPhase {
        if currentDose.lowercased() == "0" || currentDose.isEmpty {
            return weeksSinceTaper > 4
                ? .postMedication : .discontinuing
        }
        return weeksSinceTaper <= 2 ? .doseReduction : .activeTaper
    }

    private static func calorieMultiplier(phase: TaperPhase) -> Double {
        switch phase {
        case .preTaper: 1.0
        case .doseReduction: 1.05
        case .activeTaper: 1.1
        case .discontinuing: 1.15
        case .postMedication: 1.2
        }
    }

    private static func proteinMultiplier(phase: TaperPhase) -> Double {
        switch phase {
        case .preTaper: 1.0
        case .doseReduction: 1.05
        case .activeTaper: 1.1
        case .discontinuing: 1.15
        case .postMedication: 1.1
        }
    }

    private static func taperGuidance(phase: TaperPhase) -> String {
        switch phase {
        case .preTaper:
            return "Stable dose. Continue current nutrition plan."
        case .doseReduction:
            return "Appetite may increase over the next 1-2 weeks. Gradually increase portions. Keep protein target high to protect lean mass."
        case .activeTaper:
            return "Appetite returning. Focus on meal timing and protein-first eating. Volume eating with high-fiber foods helps manage hunger."
        case .discontinuing:
            return "Last dose phase. Appetite will return to baseline. Increase calories 15% but maintain protein. Weight regain is normal and expected."
        case .postMedication:
            return "Off medication. Focus on sustainable eating patterns. Protein stays elevated. Consider increasing training volume."
        }
    }
}
