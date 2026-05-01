import Foundation
import SwiftData

@Model
final class UserProfile {
    var name: String
    var createdAt: Date
    var hasCompletedOnboarding: Bool

    // Body stats
    var age: Int?
    var sex: BiologicalSex?
    var ethnicity: Ethnicity?
    var weightLbs: Double?
    var heightInches: Int?
    var goalWeightLbs: Double?

    // Medication
    var medication: Medication?
    var medicationModality: MedicationModality?
    var doseAmount: String?
    var injectionDay: Int? // 1=Sun, 2=Mon, ..., 7=Sat
    var pillTime: Date?

    // Goals & mode
    var productMode: ProductMode
    var worries: [Worry]
    var trainingLevel: TrainingLevel
    var dietaryRestrictions: [DietaryRestriction]

    // Targets (computed after onboarding)
    var proteinTargetGrams: Int
    var calorieTarget: Int
    var waterTargetLiters: Double
    var fiberTargetGrams: Int

    /// Free-text intent the user typed (or spoke) on the editorial onboarding's
    /// "in your own words" question. Optional, nil for users who completed
    /// the legacy onboarding before this field existed. Read by Mira's
    /// recommendation engine as an ongoing personalization signal.
    var openGoal: String?

    /// Free-text movement context (routine, injuries, what works for them)
    /// captured on the editorial onboarding's Movement screen. Same nil
    /// semantics as `openGoal`.
    var movementNote: String?

    /// Cognito sub the profile belongs to. Optional + nil-on-legacy keeps
    /// the migration lightweight; rows pre-dating this field decode with
    /// userId == nil and are claimed by the first signed-in user via the
    /// migration logic in `RootView` (see `MemoryAisleApp.swift`). After
    /// the rollout, every profile written by `OnboardingFlow` and the
    /// reviewer seed service stamps the current sub here so the routing
    /// can scope the correct profile per account on a shared device.
    var userId: String?

    init(
        name: String = "",
        medication: Medication? = nil,
        medicationModality: MedicationModality? = nil,
        productMode: ProductMode = .everyday,
        proteinTargetGrams: Int = 100,
        calorieTarget: Int = 1600,
        waterTargetLiters: Double = 2.5,
        fiberTargetGrams: Int = 25,
        userId: String? = nil
    ) {
        self.name = name
        self.createdAt = Date()
        self.hasCompletedOnboarding = false
        self.medication = medication
        self.medicationModality = medicationModality
        self.productMode = productMode
        self.worries = []
        self.trainingLevel = .none
        self.dietaryRestrictions = []
        self.proteinTargetGrams = proteinTargetGrams
        self.calorieTarget = calorieTarget
        self.waterTargetLiters = waterTargetLiters
        self.fiberTargetGrams = fiberTargetGrams
        self.openGoal = nil
        self.movementNote = nil
        self.userId = userId
    }
}

// MARK: - Enums

enum Medication: String, Codable, CaseIterable {
    case ozempic = "Ozempic"
    case wegovy = "Wegovy"
    case wegovyPill = "Wegovy Pill"
    case mounjaro = "Mounjaro"
    case zepbound = "Zepbound"
    case foundayo = "Foundayo"
    case rybelsus = "Rybelsus"
    case compoundedSemaglutide = "Compounded Semaglutide"
    case compoundedTirzepatide = "Compounded Tirzepatide"
    case other = "Other"
}

enum MedicationModality: String, Codable {
    case injectable
    case oralWithFasting
    case oralNoFasting

    var displayName: String {
        switch self {
        case .injectable: "Weekly Injection"
        case .oralWithFasting: "Daily Pill (fasting required)"
        case .oralNoFasting: "Daily Pill (no fasting)"
        }
    }
}

enum ProductMode: String, Codable, CaseIterable {
    case everyday = "Everyday"
    case sensitiveStomach = "Sensitive Stomach"
    case musclePreservation = "Muscle Preservation"
    case trainingPerformance = "Training Performance"
    case maintenanceTaper = "Maintenance"
}

enum BiologicalSex: String, Codable, CaseIterable {
    case male = "Male"
    case female = "Female"
    case nonBinary = "Non-binary"
    case preferNotToSay = "Prefer not to say"
}

enum Ethnicity: String, Codable, CaseIterable {
    case white = "White / Caucasian"
    case black = "Black / African American"
    case hispanic = "Hispanic / Latino"
    case eastAsian = "East Asian"
    case southAsian = "South Asian"
    case southeastAsian = "Southeast Asian"
    case middleEastern = "Middle Eastern"
    case nativeAmerican = "Native American"
    case pacificIslander = "Pacific Islander"
    case mixed = "Mixed / Multiracial"
    case other = "Other"
    case preferNotToSay = "Prefer not to say"
}

enum Worry: String, Codable, CaseIterable {
    case losingMuscle = "Losing muscle, not just fat"
    case nausea = "Nausea and food aversions"
    case notEnoughProtein = "Not getting enough protein"
    case groceryShopping = "Not knowing what to buy at the store"
    case regainingWeight = "Regaining weight if I stop"
    case hairLoss = "Hair loss or nutrient gaps"
    case lowEnergy = "Low energy for workouts"
}

enum TrainingLevel: String, Codable, CaseIterable {
    case lifts = "Yes, I lift weights"
    case cardio = "Yes, cardio / general fitness"
    case sometimes = "Sometimes"
    case none = "Not currently"
    /// Deliberate "I don't focus on exercise; manage me through nutrition only"
    /// choice, distinct from the passive `.none`. Drives `ProductMode` selection
    /// and the recommendation engine's framing (no training language).
    case nutritionOnly = "Nutrition only"

    /// Editorial-onboarding display labels (the existing rawValue strings
    /// remain the source of truth for SwiftData persistence; this is the
    /// per-screen UI copy from the new flow's Movement screen).
    var displayName: String {
        switch self {
        case .lifts:         "I lift weights regularly"
        case .cardio:        "I do cardio or general fitness"
        case .sometimes:     "I move when I can, walks, daily life"
        case .none:          "Not currently"
        case .nutritionOnly: "Don't focus on exercise, nutrition only"
        }
    }
}

enum DietaryRestriction: String, Codable, CaseIterable {
    case vegetarian = "Vegetarian"
    case vegan = "Vegan"
    case pescatarian = "Pescatarian"
    case glutenFree = "Gluten-Free"
    case dairyFree = "Dairy-Free"
    case lactoseIntolerant = "Lactose Intolerant"
    case halal = "Halal"
    case kosher = "Kosher"
    case keto = "Keto"
    case paleo = "Paleo"
    case whole30 = "Whole30"
    case lowFODMAP = "Low FODMAP"
    case nutAllergy = "Nut Allergy"
    case shellfishAllergy = "Shellfish Allergy"
    case soyFree = "Soy-Free"
    case eggFree = "Egg-Free"
    case rawFood = "Raw Food"
    case fruitarian = "Fruitarian"
    case carnivore = "Carnivore"
    case mediterranean = "Mediterranean"
}
