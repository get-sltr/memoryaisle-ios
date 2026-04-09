import Foundation
import SwiftData

struct MiraEngine {

    static func buildAnonymizedContext(
        profile: UserProfile,
        nutritionLogs: [NutritionLog],
        symptomLogs: [SymptomLog],
        cyclePhase: CyclePhase?,
        isTrainingDay: Bool
    ) -> MiraAPIClient.MiraContext {
        let todayProtein = Int(todayTotal(
            logs: nutritionLogs, keyPath: \.proteinGrams
        ))
        let todayWater = todayTotal(
            logs: nutritionLogs, keyPath: \.waterLiters
        )
        let symptomState = anonymizeSymptoms(symptomLogs)

        let anon = MedicationAnonymizer.anonymize(
            profile: profile,
            cyclePhase: cyclePhase,
            symptomState: symptomState,
            proteinConsumed: todayProtein,
            waterConsumed: todayWater,
            isTrainingDay: isTrainingDay
        )

        return MiraAPIClient.MiraContext(
            medicationClass: anon.medicationClass,
            doseTier: anon.doseTier,
            daysSinceDose: anon.daysSinceDose,
            phase: anon.phase,
            symptomState: anon.symptomState,
            mode: anon.productMode,
            proteinTarget: anon.proteinTargetGrams,
            proteinToday: anon.proteinConsumedGrams,
            waterToday: anon.waterConsumedLiters,
            trainingLevel: anon.trainingLevel,
            trainingToday: anon.trainingToday,
            calorieTarget: anon.calorieTarget,
            dietaryRestrictions: anon.dietaryRestrictions
        )
    }

    static func buildSystemPrompt(
        profile: UserProfile,
        cyclePhase: CyclePhase?,
        giTriggers: [String],
        pantryItems: [PantryItem]
    ) -> String {
        let anon = MedicationAnonymizer.anonymize(
            profile: profile,
            cyclePhase: cyclePhase,
            symptomState: "unknown",
            proteinConsumed: 0,
            waterConsumed: 0,
            isTrainingDay: false
        )

        var prompt = """
        You are Mira, the AI nutrition companion for MemoryAisle. \
        You help GLP-1 medication users eat to preserve lean mass \
        while losing fat.

        USER CONTEXT:
        - Mode: \(anon.productMode)
        - Medication class: \(anon.medicationClass)
        - Dose tier: \(anon.doseTier)
        - Training: \(anon.trainingLevel)
        - Protein target: \(anon.proteinTargetGrams)g/day
        - Calorie target: \(anon.calorieTarget)/day
        """

        if let phase = cyclePhase {
            prompt += "\n- Cycle phase: \(phase.anonymizedName)"
            prompt += "\n- Strategy: \(phase.proteinStrategy)"
        }

        if !anon.dietaryRestrictions.isEmpty {
            let joined = anon.dietaryRestrictions
                .joined(separator: ", ")
            prompt += "\n- Dietary: \(joined)"
        }

        if !giTriggers.isEmpty {
            prompt += "\n- GI triggers (avoid): "
                + giTriggers.joined(separator: ", ")
        }

        if !pantryItems.isEmpty {
            let pantry = pantryItems.prefix(20)
                .map(\.name).joined(separator: ", ")
            prompt += "\n- Pantry: \(pantry)"
        }

        prompt += """

        RULES:
        - Never diagnose medical conditions
        - Never recommend stopping or changing medication
        - Always defer medical questions to their prescriber
        - Focus on protein-first nutrition guidance
        - Acknowledge uncertainty explicitly
        - Keep responses concise and actionable
        - Adapt portion suggestions to appetite level
        - Never reference specific brand names of medications
        - Never ask for or reference the user's real name
        - When suggesting meals, include complete recipes with exact ingredient amounts and step-by-step cooking instructions
        - Include prep time and cook time in recipe steps
        - Note GLP-1 specific tips (nausea-safe variations, protein boosters)
        """

        return prompt
    }

    private static func anonymizeSymptoms(
        _ logs: [SymptomLog]
    ) -> String {
        let recent = logs.suffix(7)
        guard !recent.isEmpty else { return "none" }

        let avgNausea = Double(
            recent.reduce(0) { $0 + $1.nauseaLevel }
        ) / Double(recent.count)

        return switch avgNausea {
        case 0..<1: "none"
        case 1..<2.5: "mild_nausea"
        case 2.5..<4: "moderate_nausea"
        default: "severe_nausea"
        }
    }

    private static func todayTotal(
        logs: [NutritionLog],
        keyPath: KeyPath<NutritionLog, Double>
    ) -> Double {
        let today = Calendar.current.startOfDay(for: .now)
        return logs
            .filter { $0.date >= today }
            .reduce(0) { $0 + $1[keyPath: keyPath] }
    }
}
