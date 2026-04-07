import Foundation
import SwiftData

struct GIToleranceEngine {

    struct FoodRisk: Identifiable {
        let id = UUID()
        let foodName: String
        let triggerCount: Int
        let totalExposures: Int
        let primarySymptom: String
        let avgSeverity: Double

        var riskPercentage: Int {
            totalExposures > 0 ? (triggerCount * 100) / totalExposures : 0
        }

        var riskLevel: RiskLevel {
            if riskPercentage >= 60 { return .high }
            if riskPercentage >= 30 { return .moderate }
            return .low
        }
    }

    enum RiskLevel: String {
        case high = "Avoid"
        case moderate = "Caution"
        case low = "Safe"

        var color: String {
            switch self {
            case .high: "F87171"
            case .moderate: "FBBF24"
            case .low: "34D399"
            }
        }
    }

    static func analyzeRisks(records: [GIToleranceRecord]) -> [FoodRisk] {
        let grouped = Dictionary(grouping: records) { $0.foodName.lowercased() }

        return grouped.compactMap { foodName, records in
            let triggers = records.filter { $0.triggeredNausea || $0.triggeredBloating || $0.triggeredConstipation || $0.triggeredAversion }

            guard !triggers.isEmpty else { return nil }

            let primarySymptom: String
            let nauseaCount = triggers.filter(\.triggeredNausea).count
            let bloatingCount = triggers.filter(\.triggeredBloating).count
            let constipationCount = triggers.filter(\.triggeredConstipation).count
            let aversionCount = triggers.filter(\.triggeredAversion).count

            let maxCount = max(nauseaCount, bloatingCount, constipationCount, aversionCount)
            if maxCount == nauseaCount { primarySymptom = "Nausea" }
            else if maxCount == bloatingCount { primarySymptom = "Bloating" }
            else if maxCount == constipationCount { primarySymptom = "Constipation" }
            else { primarySymptom = "Food Aversion" }

            let avgSeverity = Double(triggers.reduce(0) { $0 + $1.severity }) / Double(triggers.count)

            return FoodRisk(
                foodName: records.first?.foodName ?? foodName,
                triggerCount: triggers.count,
                totalExposures: records.count,
                primarySymptom: primarySymptom,
                avgSeverity: avgSeverity
            )
        }
        .sorted { $0.riskPercentage > $1.riskPercentage }
    }

    static func isSafe(foodName: String, records: [GIToleranceRecord]) -> Bool {
        let risks = analyzeRisks(records: records.filter { $0.foodName.lowercased() == foodName.lowercased() })
        return risks.first?.riskLevel != .high
    }

    static func triggerFoods(records: [GIToleranceRecord]) -> [String] {
        analyzeRisks(records: records)
            .filter { $0.riskLevel == .high }
            .map(\.foodName)
    }
}
