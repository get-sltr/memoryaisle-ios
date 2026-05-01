import Foundation
import SwiftData

struct DataExportService {
    struct Options: Sendable {
        var includePhotos: Bool
    }

    struct Manifest: Codable, Sendable {
        let exportedAt: Date
        let appVersion: String
        let appBuild: String
        let photosIncluded: Bool
        let modelCounts: [String: Int]
    }

    enum ExportError: Error {
        case couldNotCreateDirectory
        case zipFailed
    }

    static func exportPackage(
        modelContext: ModelContext,
        options: Options
    ) throws -> URL {
        let exportRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("MemoryAisle-Export", isDirectory: true)
            .appendingPathComponent(Self.timestampFolderName(), isDirectory: true)

        try FileManager.default.createDirectory(at: exportRoot, withIntermediateDirectories: true)

        var counts: [String: Int] = [:]

        func writeJSON<T: PersistentModel, S: Encodable>(
            _ type: T.Type,
            path: [String],
            fileName: String,
            sortBy: [SortDescriptor<T>] = [],
            map: (T) -> S
        ) throws {
            let folder = path.reduce(exportRoot) { $0.appendingPathComponent($1, isDirectory: true) }
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

            let descriptor = FetchDescriptor<T>(sortBy: sortBy)
            let rows = try modelContext.fetch(descriptor)
            counts[String(describing: type)] = rows.count

            let url = folder.appendingPathComponent(fileName)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(rows.map(map))
            try data.write(to: url, options: [.atomic])
        }

        // Profile + medication
        try writeJSON(UserProfile.self, path: ["profile"], fileName: "user_profile.json", map: ExportUserProfile.init)
        try writeJSON(MedicationProfile.self,
                      path: ["medication"],
                      fileName: "medication_profile.json",
                      sortBy: [SortDescriptor(\.startDate, order: .reverse)],
                      map: ExportMedicationProfile.init)

        // Logs
        try writeJSON(NutritionLog.self,
                      path: ["nutrition"],
                      fileName: "nutrition_logs.json",
                      sortBy: [SortDescriptor(\.date, order: .reverse)],
                      map: ExportNutritionLog.init)
        try writeJSON(SymptomLog.self,
                      path: ["symptoms"],
                      fileName: "symptom_logs.json",
                      sortBy: [SortDescriptor(\.date, order: .reverse)],
                      map: ExportSymptomLog.init)
        try writeJSON(GIToleranceRecord.self,
                      path: ["gi_tolerance"],
                      fileName: "gi_tolerance_records.json",
                      sortBy: [SortDescriptor(\.date, order: .reverse)],
                      map: ExportGIToleranceRecord.init)

        // Meals
        try writeJSON(MealPlan.self,
                      path: ["meals"],
                      fileName: "meal_plans.json",
                      sortBy: [SortDescriptor(\.date, order: .reverse)],
                      map: ExportMealPlan.init)
        try writeJSON(Meal.self, path: ["meals"], fileName: "meals.json", map: ExportMeal.init)
        try writeJSON(FoodItem.self, path: ["meals"], fileName: "food_items.json", map: ExportFoodItem.init)

        // Kitchen
        try writeJSON(GroceryList.self, path: ["grocery"], fileName: "grocery_list.json", map: ExportGroceryList.init)
        try writeJSON(PantryItem.self, path: ["pantry"], fileName: "pantry_items.json", map: ExportPantryItem.init)

        // Progress
        try writeJSON(TrainingSession.self,
                      path: ["training"],
                      fileName: "training_sessions.json",
                      sortBy: [SortDescriptor(\.date, order: .reverse)],
                      map: ExportTrainingSession.init)
        try writeJSON(BodyComposition.self,
                      path: ["progress"],
                      fileName: "body_composition.json",
                      sortBy: [SortDescriptor(\.date, order: .reverse)],
                      map: ExportBodyComposition.init)

        // Reports + recipes + jobs
        try writeJSON(ProviderReport.self, path: ["reports"], fileName: "provider_reports.json", map: ExportProviderReport.init)
        try writeJSON(SavedRecipe.self, path: ["recipes"], fileName: "saved_recipes.json", map: ExportSavedRecipe.init)
        try writeJSON(MealGenerationJob.self, path: ["jobs"], fileName: "meal_generation_jobs.json", map: ExportMealGenerationJob.init)

        // Photos (optional)
        if options.includePhotos {
            try exportProgressPhotos(into: exportRoot.appendingPathComponent("photos", isDirectory: true))
        }

        // Manifest
        let meta = exportRoot.appendingPathComponent("meta", isDirectory: true)
        try FileManager.default.createDirectory(at: meta, withIntermediateDirectories: true)

        let manifest = Manifest(
            exportedAt: Date(),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—",
            appBuild: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—",
            photosIncluded: options.includePhotos,
            modelCounts: counts
        )

        let manifestURL = meta.appendingPathComponent("manifest.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(manifest).write(to: manifestURL, options: [.atomic])

        // Return the export folder. iOS share sheet supports sharing folders,
        // and this avoids relying on platform ZIP helpers.
        return exportRoot
    }

    private static func exportProgressPhotos(into destination: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: destination, withIntermediateDirectories: true)

        guard let documents = fm.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let source = documents.appendingPathComponent("ProgressPhotos", isDirectory: true)
        guard fm.fileExists(atPath: source.path) else { return }

        let files = (try? fm.contentsOfDirectory(at: source, includingPropertiesForKeys: nil)) ?? []
        for file in files {
            let dest = destination.appendingPathComponent(file.lastPathComponent)
            // Overwrite if already present in temp
            try? fm.removeItem(at: dest)
            try fm.copyItem(at: file, to: dest)
        }
    }

    private static func timestampFolderName() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmmss"
        return f.string(from: Date())
    }
}

// MARK: - Export snapshots (Codable, stable)

private struct ExportUserProfile: Codable, Sendable {
    let name: String
    let createdAt: Date
    let hasCompletedOnboarding: Bool
    let age: Int?
    let sex: String?
    let ethnicity: String?
    let weightLbs: Double?
    let heightInches: Int?
    let goalWeightLbs: Double?
    let medication: String?
    let medicationModality: String?
    let doseAmount: String?
    let injectionDay: Int?
    let pillTime: Date?
    let productMode: String
    let worries: [String]
    let trainingLevel: String
    let dietaryRestrictions: [String]
    let proteinTargetGrams: Int
    let calorieTarget: Int
    let waterTargetLiters: Double
    let fiberTargetGrams: Int
    let openGoal: String?
    let movementNote: String?

    init(_ row: UserProfile) {
        name = row.name
        createdAt = row.createdAt
        hasCompletedOnboarding = row.hasCompletedOnboarding
        age = row.age
        sex = row.sex?.rawValue
        ethnicity = row.ethnicity?.rawValue
        weightLbs = row.weightLbs
        heightInches = row.heightInches
        goalWeightLbs = row.goalWeightLbs
        medication = row.medication?.rawValue
        medicationModality = row.medicationModality?.rawValue
        doseAmount = row.doseAmount
        injectionDay = row.injectionDay
        pillTime = row.pillTime
        productMode = row.productMode.rawValue
        worries = row.worries.map(\.rawValue)
        trainingLevel = row.trainingLevel.rawValue
        dietaryRestrictions = row.dietaryRestrictions.map(\.rawValue)
        proteinTargetGrams = row.proteinTargetGrams
        calorieTarget = row.calorieTarget
        waterTargetLiters = row.waterTargetLiters
        fiberTargetGrams = row.fiberTargetGrams
        openGoal = row.openGoal
        movementNote = row.movementNote
    }
}

private struct ExportMedicationProfile: Codable, Sendable {
    let id: String
    let medication: String
    let modality: String
    let doseAmount: String
    let startDate: Date
    let injectionDay: Int?
    let pillTime: Date?
    let fastingWindowMinutes: Int
    let currentPhaseWeek: Int
    let isOnTaper: Bool
    let taperStartDate: Date?
    let previousDose: String?
    let notes: String?
    let providerName: String?
    let providerPhone: String?
    let pharmacyName: String?
    let pharmacyPhone: String?
    let refillDueDate: Date?
    let refillReminderEnabled: Bool?

    init(_ row: MedicationProfile) {
        id = row.id
        medication = row.medication.rawValue
        modality = row.modality.rawValue
        doseAmount = row.doseAmount
        startDate = row.startDate
        injectionDay = row.injectionDay
        pillTime = row.pillTime
        fastingWindowMinutes = row.fastingWindowMinutes
        currentPhaseWeek = row.currentPhaseWeek
        isOnTaper = row.isOnTaper
        taperStartDate = row.taperStartDate
        previousDose = row.previousDose
        notes = row.notes
        providerName = row.providerName
        providerPhone = row.providerPhone
        pharmacyName = row.pharmacyName
        pharmacyPhone = row.pharmacyPhone
        refillDueDate = row.refillDueDate
        refillReminderEnabled = row.refillReminderEnabled
    }
}

private struct ExportNutritionLog: Codable, Sendable {
    let date: Date
    let proteinGrams: Double
    let caloriesConsumed: Double
    let waterLiters: Double
    let fiberGrams: Double
    let foodName: String?

    init(_ row: NutritionLog) {
        date = row.date
        proteinGrams = row.proteinGrams
        caloriesConsumed = row.caloriesConsumed
        waterLiters = row.waterLiters
        fiberGrams = row.fiberGrams
        foodName = row.foodName
    }
}

private struct ExportSymptomLog: Codable, Sendable {
    let date: Date
    let nauseaLevel: Int
    let appetiteLevel: Int
    let energyLevel: Int
    let bloating: Bool
    let constipation: Bool
    let foodAversion: Bool
    let notes: String?

    init(_ row: SymptomLog) {
        date = row.date
        nauseaLevel = row.nauseaLevel
        appetiteLevel = row.appetiteLevel
        energyLevel = row.energyLevel
        bloating = row.bloating
        constipation = row.constipation
        foodAversion = row.foodAversion
        notes = row.notes
    }
}

private struct ExportGIToleranceRecord: Codable, Sendable {
    let foodName: String
    let date: Date
    let triggeredNausea: Bool
    let triggeredBloating: Bool
    let triggeredConstipation: Bool
    let triggeredAversion: Bool
    let severity: Int
    let notes: String?

    init(_ row: GIToleranceRecord) {
        foodName = row.foodName
        date = row.date
        triggeredNausea = row.triggeredNausea
        triggeredBloating = row.triggeredBloating
        triggeredConstipation = row.triggeredConstipation
        triggeredAversion = row.triggeredAversion
        severity = row.severity
        notes = row.notes
    }
}

private struct ExportMealPlan: Codable, Sendable {
    let id: String
    let date: Date
    let productMode: String
    let totalProteinGrams: Double
    let totalCalories: Double
    let generatedAt: Date
    let isActive: Bool
    let mealIds: [String]

    init(_ row: MealPlan) {
        id = row.id
        date = row.date
        productMode = row.productMode.rawValue
        totalProteinGrams = row.totalProteinGrams
        totalCalories = row.totalCalories
        generatedAt = row.generatedAt
        isActive = row.isActive
        mealIds = row.meals.map(\.id)
    }
}

private struct ExportMeal: Codable, Sendable {
    let id: String
    let name: String
    let mealType: String
    let proteinGrams: Double
    let caloriesTotal: Double
    let carbsGrams: Double
    let fatGrams: Double
    let fiberGrams: Double
    let prepTimeMinutes: Int
    let cookingInstructions: String?
    let ingredients: [String]
    let isNauseaSafe: Bool
    let isHighProtein: Bool
    let createdAt: Date
    let mealPlanId: String?

    init(_ row: Meal) {
        id = row.id
        name = row.name
        mealType = row.mealType.rawValue
        proteinGrams = row.proteinGrams
        caloriesTotal = row.caloriesTotal
        carbsGrams = row.carbsGrams
        fatGrams = row.fatGrams
        fiberGrams = row.fiberGrams
        prepTimeMinutes = row.prepTimeMinutes
        cookingInstructions = row.cookingInstructions
        ingredients = row.ingredients
        isNauseaSafe = row.isNauseaSafe
        isHighProtein = row.isHighProtein
        createdAt = row.createdAt
        mealPlanId = row.mealPlan?.id
    }
}

private struct ExportFoodItem: Codable, Sendable {
    let id: String
    let name: String
    let brand: String?
    let barcode: String?
    let servingSizeGrams: Double
    let proteinGrams: Double
    let caloriesPerServing: Double
    let carbsGrams: Double
    let fatGrams: Double
    let fiberGrams: Double
    let sugarGrams: Double
    let sodiumMg: Double
    let isNauseaSafe: Bool
    let giRisk: String
    let scannedAt: Date
    let source: String

    init(_ row: FoodItem) {
        id = row.id
        name = row.name
        brand = row.brand
        barcode = row.barcode
        servingSizeGrams = row.servingSizeGrams
        proteinGrams = row.proteinGrams
        caloriesPerServing = row.caloriesPerServing
        carbsGrams = row.carbsGrams
        fatGrams = row.fatGrams
        fiberGrams = row.fiberGrams
        sugarGrams = row.sugarGrams
        sodiumMg = row.sodiumMg
        isNauseaSafe = row.isNauseaSafe
        giRisk = row.giRisk.rawValue
        scannedAt = row.scannedAt
        source = row.source.rawValue
    }
}

private struct ExportGroceryList: Codable, Sendable {
    let id: String
    let createdAt: Date
    let isCompleted: Bool
    let items: [GroceryListItem]

    init(_ row: GroceryList) {
        id = row.id
        createdAt = row.createdAt
        isCompleted = row.isCompleted
        items = row.items
    }
}

private struct ExportPantryItem: Codable, Sendable {
    let name: String
    let brand: String
    let barcode: String?
    let proteinPer100g: Double
    let caloriesPer100g: Int
    let addedDate: Date
    let expiryDate: Date?
    let category: String
    let isStaple: Bool
    let isInPantry: Bool

    init(_ row: PantryItem) {
        name = row.name
        brand = row.brand
        barcode = row.barcode
        proteinPer100g = row.proteinPer100g
        caloriesPer100g = row.caloriesPer100g
        addedDate = row.addedDate
        expiryDate = row.expiryDate
        category = row.category.rawValue
        isStaple = row.isStaple
        isInPantry = row.isInPantry
    }
}

private struct ExportTrainingSession: Codable, Sendable {
    let id: String
    let date: Date
    let type: String
    let durationMinutes: Int
    let intensity: String
    let muscleGroups: [String]
    let caloriesBurned: Double?
    let notes: String?
    let sourceIsHealthKit: Bool

    init(_ row: TrainingSession) {
        id = row.id
        date = row.date
        type = row.type.rawValue
        durationMinutes = row.durationMinutes
        intensity = row.intensity.rawValue
        muscleGroups = row.muscleGroups.map(\.rawValue)
        caloriesBurned = row.caloriesBurned
        notes = row.notes
        sourceIsHealthKit = row.sourceIsHealthKit
    }
}

private struct ExportBodyComposition: Codable, Sendable {
    let id: String
    let date: Date
    let weightLbs: Double
    let bodyFatPercent: Double?
    let leanMassLbs: Double?
    let waistInches: Double?
    let source: String

    init(_ row: BodyComposition) {
        id = row.id
        date = row.date
        weightLbs = row.weightLbs
        bodyFatPercent = row.bodyFatPercent
        leanMassLbs = row.leanMassLbs
        waistInches = row.waistInches
        source = row.source.rawValue
    }
}

private struct ExportProviderReport: Codable, Sendable {
    let id: String
    let generatedAt: Date
    let startDate: Date
    let endDate: Date
    let avgProteinGrams: Double
    let proteinHitRate: Double
    let avgCalories: Double
    let avgWaterLiters: Double
    let weightStart: Double?
    let weightEnd: Double?
    let weightChange: Double?
    let leanMassChange: Double?
    let avgNauseaLevel: Double
    let avgEnergyLevel: Double
    let symptomDays: Int
    let trainingDays: Int
    let medicationAdherence: Double
    let mealPlanAdherence: Double
    let notesForProvider: String?

    init(_ row: ProviderReport) {
        id = row.id
        generatedAt = row.generatedAt
        startDate = row.startDate
        endDate = row.endDate
        avgProteinGrams = row.avgProteinGrams
        proteinHitRate = row.proteinHitRate
        avgCalories = row.avgCalories
        avgWaterLiters = row.avgWaterLiters
        weightStart = row.weightStart
        weightEnd = row.weightEnd
        weightChange = row.weightChange
        leanMassChange = row.leanMassChange
        avgNauseaLevel = row.avgNauseaLevel
        avgEnergyLevel = row.avgEnergyLevel
        symptomDays = row.symptomDays
        trainingDays = row.trainingDays
        medicationAdherence = row.medicationAdherence
        mealPlanAdherence = row.mealPlanAdherence
        notesForProvider = row.notesForProvider
    }
}

private struct ExportSavedRecipe: Codable, Sendable {
    let title: String
    let bodyText: String
    let categoryRaw: String
    let savedAt: Date
    let kindRaw: String?
    let savedCalories: Int?
    let savedProteinG: Int?
    let savedFatG: Int?
    let savedCarbsG: Int?

    init(_ row: SavedRecipe) {
        title = row.title
        bodyText = row.bodyText
        categoryRaw = row.categoryRaw
        savedAt = row.savedAt
        kindRaw = row.kindRaw
        savedCalories = row.savedCalories
        savedProteinG = row.savedProteinG
        savedFatG = row.savedFatG
        savedCarbsG = row.savedCarbsG
    }
}

private struct ExportMealGenerationJob: Codable, Sendable {
    let id: String
    let requestedAt: Date
    let startedAt: Date?
    let completedAt: Date?
    let status: String
    let firstDate: Date
    let totalDays: Int
    let daysCompleted: Int
    let daysFailed: Int
    let lastError: String?
    let trigger: String

    init(_ row: MealGenerationJob) {
        id = row.id
        requestedAt = row.requestedAt
        startedAt = row.startedAt
        completedAt = row.completedAt
        status = row.status.rawValue
        firstDate = row.firstDate
        totalDays = row.totalDays
        daysCompleted = row.daysCompleted
        daysFailed = row.daysFailed
        lastError = row.lastError
        trigger = row.trigger.rawValue
    }
}

