import Combine
import Foundation
import SwiftData

@MainActor
final class MacroTracker: ObservableObject {
    private let modelContext: ModelContext

    @Published var todayProtein: Double = 0
    @Published var todayCalories: Double = 0
    @Published var todayWater: Double = 0
    @Published var todayFiber: Double = 0
    @Published var proteinDeficit: Double = 0
    @Published var mealsLoggedToday: Int = 0

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func refreshToday(target: UserProfile?) {
        let today = Calendar.current.startOfDay(for: .now)
        let tomorrow = Calendar.current.date(
            byAdding: .day, value: 1, to: today
        ) ?? today

        let predicate = #Predicate<NutritionLog> {
            $0.date >= today && $0.date < tomorrow
        }
        let descriptor = FetchDescriptor(predicate: predicate)
        let logs = (try? modelContext.fetch(descriptor)) ?? []

        todayProtein = logs.reduce(0) { $0 + $1.proteinGrams }
        todayCalories = logs.reduce(0) { $0 + $1.caloriesConsumed }
        todayWater = logs.reduce(0) { $0 + $1.waterLiters }
        todayFiber = logs.reduce(0) { $0 + $1.fiberGrams }
        mealsLoggedToday = logs.count

        let proteinTarget = Double(target?.proteinTargetGrams ?? 100)
        proteinDeficit = max(0, proteinTarget - todayProtein)
    }

    func logMeal(
        protein: Double,
        calories: Double,
        water: Double = 0,
        fiber: Double = 0
    ) {
        let log = NutritionLog(
            proteinGrams: protein,
            caloriesConsumed: calories,
            waterLiters: water,
            fiberGrams: fiber
        )
        modelContext.insert(log)
    }

    func logWater(liters: Double) {
        let today = Calendar.current.startOfDay(for: .now)
        let tomorrow = Calendar.current.date(
            byAdding: .day, value: 1, to: today
        ) ?? today

        let predicate = #Predicate<NutritionLog> {
            $0.date >= today && $0.date < tomorrow
        }
        let descriptor = FetchDescriptor(predicate: predicate)
        let logs = (try? modelContext.fetch(descriptor)) ?? []

        if let latestLog = logs.last {
            latestLog.waterLiters += liters
        } else {
            let log = NutritionLog(waterLiters: liters)
            modelContext.insert(log)
        }
        todayWater += liters
    }

    func weeklyAverage() -> (protein: Double, calories: Double) {
        let weekAgo = Calendar.current.date(
            byAdding: .day, value: -7, to: .now
        ) ?? .now

        let predicate = #Predicate<NutritionLog> {
            $0.date >= weekAgo
        }
        let descriptor = FetchDescriptor(predicate: predicate)
        let logs = (try? modelContext.fetch(descriptor)) ?? []

        guard !logs.isEmpty else { return (0, 0) }

        let days = Set(
            logs.map { Calendar.current.startOfDay(for: $0.date) }
        ).count
        let divisor = Double(max(1, days))

        let totalProtein = logs.reduce(0) { $0 + $1.proteinGrams }
        let totalCals = logs.reduce(0) { $0 + $1.caloriesConsumed }

        return (totalProtein / divisor, totalCals / divisor)
    }

    func proteinHitRate(
        targetGrams: Int,
        days: Int = 7
    ) -> Double {
        let start = Calendar.current.date(
            byAdding: .day, value: -days, to: .now
        ) ?? .now

        let predicate = #Predicate<NutritionLog> {
            $0.date >= start
        }
        let descriptor = FetchDescriptor(predicate: predicate)
        let logs = (try? modelContext.fetch(descriptor)) ?? []

        let dailyTotals = Dictionary(
            grouping: logs,
            by: { Calendar.current.startOfDay(for: $0.date) }
        ).mapValues { $0.reduce(0) { $0 + $1.proteinGrams } }

        guard !dailyTotals.isEmpty else { return 0 }

        let hitDays = dailyTotals.values.filter {
            $0 >= Double(targetGrams) * 0.9
        }.count

        return Double(hitDays) / Double(dailyTotals.count)
    }
}
