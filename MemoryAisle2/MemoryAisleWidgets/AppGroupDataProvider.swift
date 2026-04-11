import Foundation
import SwiftData

struct AppGroupDataProvider {
    static let appGroupId = "group.com.sltrdigital.memoryaisle"

    static var sharedContainerURL: URL {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupId
        ) ?? URL.documentsDirectory
    }

    static var sharedModelContainer: ModelContainer? {
        let schema = Schema([
            UserProfile.self,
            NutritionLog.self,
            MealPlan.self,
            Meal.self,
        ])
        let config = ModelConfiguration(
            schema: schema,
            url: sharedContainerURL.appendingPathComponent("shared.store"),
            allowsSave: false
        )
        return try? ModelContainer(for: schema, configurations: [config])
    }

    @MainActor
    static func todayNutrition() -> (protein: Double, water: Double) {
        guard let container = sharedModelContainer else { return (0, 0) }
        let context = container.mainContext
        let today = Calendar.current.startOfDay(for: .now)

        let descriptor = FetchDescriptor<NutritionLog>(
            predicate: #Predicate { $0.date >= today }
        )
        let logs = (try? context.fetch(descriptor)) ?? []

        let protein = logs.reduce(0) { $0 + $1.proteinGrams }
        let water = logs.reduce(0) { $0 + $1.waterLiters }
        return (protein, water)
    }

    @MainActor
    static func userTargets() -> (protein: Int, water: Double) {
        guard let container = sharedModelContainer else { return (140, 2.5) }
        let context = container.mainContext
        let descriptor = FetchDescriptor<UserProfile>()
        let profile = (try? context.fetch(descriptor))?.first
        return (
            profile?.proteinTargetGrams ?? 140,
            profile?.waterTargetLiters ?? 2.5
        )
    }

    @MainActor
    static func nextMeal() -> Meal? {
        guard let container = sharedModelContainer else { return nil }
        let context = container.mainContext
        let today = Calendar.current.startOfDay(for: .now)

        let descriptor = FetchDescriptor<MealPlan>(
            predicate: #Predicate { $0.date >= today && $0.isActive },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        guard let plan = (try? context.fetch(descriptor))?.first else {
            return nil
        }
        return plan.meals.first
    }
}
