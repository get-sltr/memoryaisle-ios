import Foundation

struct BarcodeInterpreter {

    static func interpret(nutrition: NutritionData) -> ScannedProduct {
        let verdict = judgeVerdict(nutrition)
        let nauseaRisk = nutrition.fat > 15
        let reason = buildReason(nutrition, verdict: verdict)

        return ScannedProduct(
            barcode: "",
            name: nutrition.name,
            brand: nutrition.brand,
            servingSize: nutrition.servingSize,
            protein: Int(nutrition.protein),
            calories: nutrition.calories,
            fat: Int(nutrition.fat),
            carbs: Int(nutrition.carbs),
            fiber: Int(nutrition.fiber),
            sodium: nutrition.sodium,
            verdict: verdict,
            nauseaRisk: nauseaRisk,
            reason: reason
        )
    }

    private static func judgeVerdict(_ n: NutritionData) -> ScanVerdict {
        // High protein, reasonable calories = good
        if n.protein >= 15 && n.fat <= 12 {
            return .good
        }

        // Decent protein or high fiber = okay
        if n.protein >= 8 || n.fiber >= 5 {
            return .okay
        }

        // Low protein + high fat or sugar = skip
        if n.protein < 5 && (n.fat > 15 || n.sugar > 15) {
            return .skip
        }

        // High fat slows gastric emptying, bad for GLP-1 users
        if n.fat > 20 {
            return .skip
        }

        return .okay
    }

    private static func buildReason(_ n: NutritionData, verdict: ScanVerdict) -> String {
        switch verdict {
        case .good:
            if n.protein >= 20 {
                return "\(Int(n.protein))g protein per serving. Excellent choice for hitting your daily target. Low fat means easy digestion."
            }
            return "\(Int(n.protein))g protein with manageable fat. Good addition to your plan."

        case .okay:
            if n.fiber >= 5 {
                return "Good fiber source (\(Int(n.fiber))g) but only \(Int(n.protein))g protein. Pair with a protein source."
            }
            return "\(Int(n.protein))g protein. Not bad, but there are higher-protein options. Works in a pinch."

        case .skip:
            if n.fat > 20 {
                return "High fat (\(Int(n.fat))g) slows gastric emptying. Can worsen nausea on GLP-1s. Only \(Int(n.protein))g protein."
            }
            if n.sugar > 15 {
                return "High sugar (\(Int(n.sugar))g) with minimal protein (\(Int(n.protein))g). Empty calories that won't help your targets."
            }
            return "Low protein, not ideal for your goals. Look for something with 15g+ protein per serving."
        }
    }
}
