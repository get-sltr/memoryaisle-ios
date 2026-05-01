import Foundation
import SwiftData

enum LocalDataPurgeService {
    /// Deletes all local SwiftData rows and on-device progress photos.
    /// Does NOT delete the Cognito account and does NOT sign the user out.
    @MainActor
    static func purgeAll(modelContext: ModelContext) async {
        purgeSwiftData(modelContext: modelContext)
        purgeProgressPhotos()
    }

    @MainActor
    private static func purgeSwiftData(modelContext: ModelContext) {
        func deleteAll<T: PersistentModel>(_ type: T.Type) {
            let descriptor = FetchDescriptor<T>()
            let rows = (try? modelContext.fetch(descriptor)) ?? []
            for row in rows {
                modelContext.delete(row)
            }
        }

        // Keep this list aligned with the app's `modelContainer(for:)`.
        deleteAll(UserProfile.self)
        deleteAll(NutritionLog.self)
        deleteAll(SymptomLog.self)
        deleteAll(PantryItem.self)
        deleteAll(GIToleranceRecord.self)
        deleteAll(MealPlan.self)
        deleteAll(Meal.self)
        deleteAll(FoodItem.self)
        deleteAll(GroceryList.self)
        deleteAll(MedicationProfile.self)
        deleteAll(TrainingSession.self)
        deleteAll(BodyComposition.self)
        deleteAll(ProviderReport.self)
        deleteAll(SavedRecipe.self)
        deleteAll(MealGenerationJob.self)

        do {
            try modelContext.save()
        } catch {
            // Best-effort purge. If save fails, the app will still be forced
            // through onboarding when we clear the flags.
        }
    }

    private static func purgeProgressPhotos() {
        let fm = FileManager.default
        guard let documents = fm.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let photos = documents.appendingPathComponent("ProgressPhotos", isDirectory: true)
        try? fm.removeItem(at: photos)
    }
}

