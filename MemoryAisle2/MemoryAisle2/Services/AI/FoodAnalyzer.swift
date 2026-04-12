import Foundation
import OSLog
import SwiftData

@MainActor
final class FoodAnalyzer {
    private let apiClient = MiraAPIClient()
    private let logger = Logger(subsystem: "com.memoryaisle.app", category: "FoodAnalyzer")
    private(set) var lastAnalysisError: String?

    struct Analysis: Sendable {
        let foodName: String
        let estimatedProtein: Double
        let estimatedCalories: Double
        let estimatedCarbs: Double
        let estimatedFat: Double
        let estimatedFiber: Double
        let isNauseaSafe: Bool
        let glp1Verdict: Verdict
        let explanation: String
        let suggestions: [String]
    }

    enum Verdict: String, Sendable {
        case good = "Good Choice"
        case okay = "Okay"
        case skip = "Skip"
    }

    func analyzeBarcodeResult(
        foodName: String,
        nutrition: NutritionData,
        profile: UserProfile,
        cyclePhase: CyclePhase?,
        giTriggers: [String]
    ) async throws -> Analysis {
        let proteinDensity = nutrition.protein > 0
            ? (nutrition.protein * 4) / max(1, Double(nutrition.calories))
            : 0

        let isHighFat = nutrition.fat > 15
        let isHighProtein = nutrition.protein >= 15
        let triggersGI = giTriggers.contains { trigger in
            foodName.lowercased().contains(trigger.lowercased())
        }

        let verdict: Verdict
        if triggersGI {
            verdict = .skip
        } else if isHighProtein && proteinDensity > 0.25 {
            verdict = .good
        } else if isHighFat && !isHighProtein {
            verdict = .skip
        } else {
            verdict = .okay
        }

        let nauseaSafe = !isHighFat
            && nutrition.fiber < 8
            && !triggersGI

        let anon = MedicationAnonymizer.anonymize(
            profile: profile,
            cyclePhase: cyclePhase,
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
            proteinToday: nil,
            waterToday: nil,
            trainingLevel: anon.trainingLevel,
            trainingToday: nil,
            calorieTarget: anon.calorieTarget,
            dietaryRestrictions: anon.dietaryRestrictions
        )

        let prompt = """
        Analyze this food for a GLP-1 user: \(foodName). \
        Protein: \(nutrition.protein)g, \
        Calories: \(nutrition.calories), \
        Fat: \(nutrition.fat)g. \
        Their protein target is \(anon.proteinTargetGrams)g/day. \
        Give a 1-2 sentence verdict and one suggestion. \
        Format: VERDICT|explanation|suggestion
        """

        var explanation = "\(nutrition.protein)g protein, "
            + "\(nutrition.calories) cal"
        var suggestions: [String] = []

        do {
            let response = try await apiClient.send(
                message: prompt, context: context
            )
            lastAnalysisError = nil
            let parts = response.components(separatedBy: "|")
            if parts.count >= 2 {
                explanation = parts[1].trimmingCharacters(
                    in: .whitespaces
                )
            }
            if parts.count >= 3 {
                suggestions = [parts[2].trimmingCharacters(
                    in: .whitespaces
                )]
            }
        } catch {
            lastAnalysisError = error.localizedDescription
            logger.error("Mira analysis failed: \(error.localizedDescription, privacy: .public)")
        }

        return Analysis(
            foodName: foodName,
            estimatedProtein: nutrition.protein,
            estimatedCalories: Double(nutrition.calories),
            estimatedCarbs: nutrition.carbs,
            estimatedFat: nutrition.fat,
            estimatedFiber: nutrition.fiber,
            isNauseaSafe: nauseaSafe,
            glp1Verdict: verdict,
            explanation: explanation,
            suggestions: suggestions
        )
    }

    func analyzePhoto(
        imageData: Data,
        profile: UserProfile
    ) async throws -> Analysis {
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
            daysSinceDose: nil,
            phase: nil,
            symptomState: nil,
            mode: anon.productMode,
            proteinTarget: anon.proteinTargetGrams,
            proteinToday: nil,
            waterToday: nil,
            trainingLevel: anon.trainingLevel,
            trainingToday: nil,
            calorieTarget: anon.calorieTarget,
            dietaryRestrictions: anon.dietaryRestrictions
        )

        let prompt = """
        A user photographed their meal. Estimate the macros. \
        Their daily protein target is \(anon.proteinTargetGrams)g. \
        Respond in format: \
        NAME|protein_g|calories|carbs_g|fat_g|fiber_g|\
        nausea_safe(true/false)|verdict(good/okay/skip)|explanation
        """

        let response = try await apiClient.send(
            message: prompt, context: context, imageData: imageData
        )

        return parsePhotoAnalysis(response)
    }

    private func parsePhotoAnalysis(_ response: String) -> Analysis {
        let parts = response.components(separatedBy: "|")

        guard parts.count >= 8 else {
            return Analysis(
                foodName: "Unknown meal",
                estimatedProtein: 0, estimatedCalories: 0,
                estimatedCarbs: 0, estimatedFat: 0, estimatedFiber: 0,
                isNauseaSafe: true, glp1Verdict: .okay,
                explanation: response, suggestions: []
            )
        }

        let name = parts[0].trimmingCharacters(in: .whitespaces)
        let protein = Double(parts[1].trimmingCharacters(
            in: .whitespaces
        )) ?? 0
        let calories = Double(parts[2].trimmingCharacters(
            in: .whitespaces
        )) ?? 0
        let carbs = Double(parts[3].trimmingCharacters(
            in: .whitespaces
        )) ?? 0
        let fat = Double(parts[4].trimmingCharacters(
            in: .whitespaces
        )) ?? 0
        let fiber = Double(parts[5].trimmingCharacters(
            in: .whitespaces
        )) ?? 0
        let nauseaSafe = parts[6].trimmingCharacters(
            in: .whitespaces
        ).lowercased() == "true"
        let verdictRaw = parts[7].trimmingCharacters(
            in: .whitespaces
        ).lowercased()
        let verdict: Verdict = switch verdictRaw {
        case "good": .good
        case "skip": .skip
        default: .okay
        }

        let explanation = parts.count > 8
            ? parts[8].trimmingCharacters(in: .whitespaces)
            : "\(Int(protein))g protein, \(Int(calories)) cal"

        return Analysis(
            foodName: name,
            estimatedProtein: protein,
            estimatedCalories: calories,
            estimatedCarbs: carbs,
            estimatedFat: fat,
            estimatedFiber: fiber,
            isNauseaSafe: nauseaSafe,
            glp1Verdict: verdict,
            explanation: explanation,
            suggestions: []
        )
    }
}
