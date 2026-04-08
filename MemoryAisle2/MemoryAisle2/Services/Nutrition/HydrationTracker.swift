import Combine
import Foundation
import SwiftData

@MainActor
final class HydrationTracker: ObservableObject {
    private let modelContext: ModelContext

    @Published var todayLiters: Double = 0
    @Published var targetLiters: Double = 2.5
    @Published var progress: Double = 0
    @Published var reminderNeeded: Bool = false

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func refresh(userTarget: Double) {
        targetLiters = userTarget
        todayLiters = fetchTodayWater()
        progress = min(1.0, todayLiters / max(0.1, targetLiters))
        reminderNeeded = shouldRemind()
    }

    func addWater(liters: Double) {
        let today = Calendar.current.startOfDay(for: .now)
        let tomorrow = Calendar.current.date(
            byAdding: .day, value: 1, to: today
        ) ?? today

        let predicate = #Predicate<NutritionLog> {
            $0.date >= today && $0.date < tomorrow
        }
        let descriptor = FetchDescriptor(predicate: predicate)
        let logs = (try? modelContext.fetch(descriptor)) ?? []

        if let latest = logs.last {
            latest.waterLiters += liters
        } else {
            modelContext.insert(NutritionLog(waterLiters: liters))
        }

        todayLiters += liters
        progress = min(1.0, todayLiters / max(0.1, targetLiters))
    }

    func weeklyAverage() -> Double {
        let weekAgo = Calendar.current.date(
            byAdding: .day, value: -7, to: .now
        ) ?? .now

        let predicate = #Predicate<NutritionLog> {
            $0.date >= weekAgo
        }
        let descriptor = FetchDescriptor(predicate: predicate)
        let logs = (try? modelContext.fetch(descriptor)) ?? []

        guard !logs.isEmpty else { return 0 }

        let days = Set(
            logs.map { Calendar.current.startOfDay(for: $0.date) }
        ).count

        let total = logs.reduce(0.0) { $0 + $1.waterLiters }
        return total / Double(max(1, days))
    }

    static func adjustedTarget(
        baseLiters: Double,
        nauseaRisk: Double,
        isTrainingDay: Bool
    ) -> Double {
        var target = baseLiters

        if nauseaRisk > 0.5 {
            target += 0.5
        }

        if isTrainingDay {
            target += 0.5
        }

        return min(4.0, target)
    }

    private func fetchTodayWater() -> Double {
        let today = Calendar.current.startOfDay(for: .now)
        let tomorrow = Calendar.current.date(
            byAdding: .day, value: 1, to: today
        ) ?? today

        let predicate = #Predicate<NutritionLog> {
            $0.date >= today && $0.date < tomorrow
        }
        let descriptor = FetchDescriptor(predicate: predicate)
        let logs = (try? modelContext.fetch(descriptor)) ?? []

        return logs.reduce(0.0) { $0 + $1.waterLiters }
    }

    private func shouldRemind() -> Bool {
        let hour = Calendar.current.component(.hour, from: .now)
        let expectedProgress = Double(hour) / 16.0

        return progress < expectedProgress * 0.7 && hour >= 9
    }
}
