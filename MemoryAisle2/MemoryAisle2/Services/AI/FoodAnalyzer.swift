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

    /// Raised when Mira returns a conversational/refusal response instead of
    /// the pipe-delimited contract — or when she returns the contract but
    /// every numeric macro lands at zero, which is the same signal in
    /// disguise. We surface this as an explicit error so MealPhotoView
    /// stops at the error view (and never persists a zero-macro
    /// NutritionLog) rather than silently rendering an "Unknown meal" 0/0/0
    /// result that the user can still tap "Log this meal" on.
    enum AnalysisError: LocalizedError {
        case notRecognized(reply: String)

        var errorDescription: String? {
            switch self {
            case .notRecognized:
                return "Mira couldn't read the macros from this photo. Try a closer shot, or describe what you ate in chat."
            }
        }

        var conversationalReply: String? {
            switch self {
            case .notRecognized(let reply): return reply
            }
        }
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

        // Tight, no-room-to-refuse prompt. The earlier version was soft
        // enough that Claude sometimes redirected to "I focus on nutrition
        // guidance, not photos" and returned conversational prose, which
        // landed in the dashboard as zero-macro phantom logs. We require
        // the exact pipe format and ban preamble. If the photo really
        // isn't food, we instruct an empty NAME field so the parser can
        // surface a clean error instead of a fabricated estimate.
        let prompt = """
        Estimate macros for this meal photo. The user's daily protein \
        target is \(anon.proteinTargetGrams)g.

        Respond with ONE LINE in this exact pipe-delimited format and \
        nothing else (no preamble, no markdown, no commentary):

        NAME|protein_g|calories|carbs_g|fat_g|fiber_g|nausea_safe(true/false)|verdict(good/okay/skip)|explanation

        Rules:
        - Estimate to the best of your ability from the photo. A rough \
          estimate is better than a refusal.
        - Macros must be positive integers when food is visible.
        - If the photo is clearly not food, return: NOT_FOOD|0|0|0|0|0|true|okay|This photo doesn't look like a meal.
        - Do not refuse, hedge, or ask the user a question. Output the line.
        """

        let response = try await apiClient.send(
            message: prompt, context: context, imageData: imageData
        )

        let analysis = try parsePhotoAnalysis(response)

        // Defense-in-depth: if Mira followed the format but returned all
        // zeros (e.g. produced "Unknown|0|0|0|0|0|true|okay|..." as a soft
        // refusal), treat it the same as a refusal. Persisting a zero
        // NutritionLog row is the bug we're trying to prevent.
        if analysis.estimatedProtein <= 0
            && analysis.estimatedCalories <= 0
            && analysis.estimatedFat <= 0
            && analysis.estimatedCarbs <= 0 {
            throw AnalysisError.notRecognized(reply: analysis.explanation)
        }

        return analysis
    }

    private func parsePhotoAnalysis(_ response: String) throws -> Analysis {
        let parts = response.components(separatedBy: "|")

        // Mira sometimes refuses photo analysis ("I focus on nutrition
        // guidance, not photos") and replies in prose. The legacy code
        // returned an "Unknown meal" 0/0/0 placeholder which then rendered
        // as a result the user could tap "Log this meal" on, persisting
        // empty NutritionLog rows. Treat both shapes — non-conforming
        // response and conforming-but-all-zero macros — as failures.
        guard parts.count >= 8 else {
            throw AnalysisError.notRecognized(reply: response)
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
