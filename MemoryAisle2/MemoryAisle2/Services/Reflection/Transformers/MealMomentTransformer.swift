import Foundation

/// Turns NutritionLog rows that represent real meal events (non-nil
/// foodName) into Reflection moments. Logs without a foodName — legacy
/// rows, seed data, and hydration-only rows from HydrationTracker — are
/// skipped so the timeline only surfaces intentional meal logs.
///
/// The earliest named meal becomes a milestone ("Your first meal"); all
/// later meals are standard moments. Photo bytes pass straight through to
/// the moment so the Photos filter chip picks them up for free.
struct MealMomentTransformer: MomentTransformer {

    func moments(from records: ReflectionSourceRecords) throws -> [ReflectionMoment] {
        let namedMeals = records.nutritionLogs
            .filter { ($0.foodName ?? "").isEmpty == false }
            .sorted { $0.date < $1.date }

        guard !namedMeals.isEmpty else { return [] }

        var result: [ReflectionMoment] = []
        for (index, log) in namedMeals.enumerated() {
            let isFirst = index == 0
            let name = log.foodName ?? "Meal"

            result.append(
                ReflectionMoment(
                    id: momentID(for: log, name: name, isFirst: isFirst),
                    date: log.date,
                    type: .mealMoment,
                    category: isFirst ? .milestone : .standard,
                    title: isFirst ? "Your first meal" : name,
                    description: description(
                        name: name,
                        protein: log.proteinGrams,
                        calories: log.caloriesConsumed,
                        isFirst: isFirst
                    ),
                    photoData: log.photoData,
                    metadataLabel: metadataLabel(for: log)
                )
            )
        }
        return result
    }

    private func momentID(for log: NutritionLog, name: String, isFirst: Bool) -> String {
        let stamp = Int(log.date.timeIntervalSince1970)
        let slug = name.lowercased().replacingOccurrences(of: " ", with: "-")
        let prefix = isFirst ? "mealMoment-first" : "mealMoment"
        return "\(prefix)-\(stamp)-\(slug)"
    }

    private func description(
        name: String,
        protein: Double,
        calories: Double,
        isFirst: Bool
    ) -> String {
        let proteinG = Int(protein.rounded())
        if isFirst {
            if proteinG > 0 {
                return "\(name). \(proteinG)g of real fuel. The journey starts right here."
            }
            return "\(name). The journey starts right here."
        }
        return celebrationLine(protein: proteinG, calories: calories)
    }

    /// Varied celebration lines so a day of logged meals doesn't read as
    /// a formulaic stamp. Cheerleader tone, no judgment, no banned words.
    private func celebrationLine(protein proteinG: Int, calories: Double) -> String {
        if proteinG >= 35 {
            return "\(proteinG)g protein in. Your muscles felt that one."
        }
        if proteinG >= 20 {
            return "\(proteinG)g protein. Real fuel, real care."
        }
        if proteinG > 0 {
            return "\(proteinG)g protein. You showed up for yourself."
        }
        return "You logged it. That's the habit building."
    }

    private func metadataLabel(for log: NutritionLog) -> String? {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return "LOGGED \(f.string(from: log.date).uppercased())"
    }
}
