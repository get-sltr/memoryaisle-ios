import SwiftUI
import SwiftData

struct OnboardingFlow: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Environment(SubscriptionManager.self) private var subscriptionManager
    @State private var showOnboarding = true
    @State private var profile = OnboardingProfile()

    var body: some View {
        ZStack {
            if showOnboarding {
                EditorialOnboardingFlow(
                    profile: $profile,
                    onComplete: { completeOnboarding() }
                )
                .transition(.opacity)
            }
        }
    }

    // MARK: - Complete

    private func completeOnboarding() {
        let user = UserProfile(
            name: profile.name,
            medication: profile.medication,
            medicationModality: profile.modality,
            productMode: deriveMode(),
            proteinTargetGrams: deriveProteinTarget(),
            userId: appState.cognitoUserId
        )
        user.hasCompletedOnboarding = true
        user.worries = profile.worries
        user.trainingLevel = profile.trainingLevel
        user.dietaryRestrictions = profile.dietaryRestrictions
        user.doseAmount = profile.doseAmount
        user.injectionDay = profile.injectionDay
        user.pillTime = profile.pillTime
        user.age = profile.age
        user.sex = profile.sex
        user.ethnicity = profile.ethnicity
        user.weightLbs = profile.weightLbs
        user.heightInches = profile.heightInches
        user.goalWeightLbs = profile.goalWeightLbs
        user.openGoal = profile.openGoal
        user.movementNote = profile.movementNote

        // Medication start date — the editorial flow's MedicationStartScreen
        // sets both `profile.medicationStartDate` and the legacy UserDefaults
        // key the dashboard's cycle-day calculation reads. Mirror the
        // UserDefaults write here as a safety net for any path that bypassed
        // that screen (skip → no value).
        if let startDate = profile.medicationStartDate {
            UserDefaults.standard.set(startDate, forKey: "medicationStartDate")
        }

        modelContext.insert(user)

        // Record the journey start date so Reflection can compute "days since"
        // and anchor anniversary milestones.
        UserDefaults.standard.set(Date(), forKey: "journeyStartDate")

        // If the user provided a starting photo, create a Day 1 BodyComposition
        // record. This anchors Reflection's hero comparison and produces the
        // first-photo milestone moment.
        if let photoData = profile.startingPhotoData,
           let weightLbs = profile.weightLbs {
            let starting = BodyComposition(
                date: .now,
                weightLbs: weightLbs,
                source: .manual,
                photoData: photoData
            )
            modelContext.insert(starting)
        }

        appState.hasCompletedOnboarding = true

        // Kick off the 7-day Mira meal plan as part of signup. Honors the
        // weekly_meal_plan_enabled feature flag and the signup quota; the
        // orchestrator persists a MealGenerationJob so the work survives an
        // app kill mid-generation. User transitions to Today immediately while
        // generation runs in the background; MealsView surfaces progress.
        let isPro = subscriptionManager.tier == .pro
        let orchestrator = WeeklyMealPlanOrchestrator()
        let outcome = orchestrator.startWeekly(
            profile: user,
            giTriggers: [],
            pantryItems: [],
            startDate: .now,
            days: 7,
            trigger: .signup,
            isPro: isPro,
            context: modelContext
        )
        if case .rejected(let reason) = outcome {
            // Failure here doesn't block onboarding completion — the user can
            // always tap regenerate from MealsView. We log so we can spot
            // unexpected rejections (flag pulled, etc.) in CloudWatch.
            appState.lastWeeklyGenRejection = reason
        }
    }

    private func deriveMode() -> ProductMode {
        // Bias toward sensitive stomach if the editorial onboarding's
        // appetite screen indicated significant suppression.
        if let appetite = profile.appetiteState,
           appetite == .nausea || appetite == .noAppeal {
            return .sensitiveStomach
        }
        if !profile.isOnGLP1 {
            if profile.trainingLevel == .lifts { return .musclePreservation }
            if profile.trainingLevel == .cardio { return .trainingPerformance }
            return .everyday
        }
        if profile.worries.contains(.nausea) { return .sensitiveStomach }
        if profile.trainingLevel == .lifts { return .musclePreservation }
        return .everyday
    }

    private func deriveProteinTarget() -> Int {
        if let weight = profile.weightLbs {
            let leanMassRatio: Double = profile.sex == .female ? 0.72 : 0.78
            let leanMass = weight * leanMassRatio
            let gramsPerLb: Double = switch profile.trainingLevel {
            case .lifts:         1.2
            case .cardio:        1.0
            case .sometimes:     0.9
            case .none:          0.8
            case .nutritionOnly: 0.8
            }
            return Int(leanMass * gramsPerLb)
        }

        switch profile.trainingLevel {
        case .lifts:         return 150
        case .cardio:        return 130
        case .sometimes:     return 120
        case .none:          return 100
        case .nutritionOnly: return 100
        }
    }
}

// MARK: - Profile Accumulator

struct OnboardingProfile {
    var isOnGLP1 = true
    var medication: Medication?
    var modality: MedicationModality?
    var doseAmount: String?
    var injectionDay: Int?
    var injectionsPerWeek: Int?
    var pillTime: Date?
    var pillTimesPerDay: Int?
    var name: String = ""
    var age: Int?
    var sex: BiologicalSex?
    var ethnicity: Ethnicity?
    var weightLbs: Double?
    var heightInches: Int?
    var goalWeightLbs: Double?
    var startingPhotoData: Data?   // transient, carries photo to completeOnboarding
    var worries: [Worry] = []
    var trainingLevel: TrainingLevel = .none
    var dietaryRestrictions: [DietaryRestriction] = []

    // Editorial onboarding additions (defaults preserve back-compat with any
    // in-flight legacy onboarding state — empty list, nil strings).

    /// Top-of-mind priorities ranked top-3, captured on Screen 02. Drives
    /// branch-soft routing: presence of `.glp1Appetite` activates Screens 11-14.
    var priorities: [Priority] = []

    /// Free-text "in your own words" goal from Screen 03. Optional.
    var openGoal: String?

    /// Free-text movement context from Screen 10. Optional.
    var movementNote: String?

    /// Date the user reports they started their current GLP-1, captured on
    /// Screen 13. Persisted into UserDefaults at completion (matches the
    /// existing legacy onboarding's storage convention) and drives the
    /// dashboard's cycle-day calculation.
    var medicationStartDate: Date?

    /// Appetite snapshot from Screen 14, GLP-1 path only. Maps to ProductMode
    /// .sensitiveStomach when the answer indicates significant suppression.
    var appetiteState: AppetiteState?
}

/// User-reported appetite state captured at the end of the GLP-1 path.
/// Used to bias `ProductMode` selection (significant nausea or no-appeal
/// answers shift the user into `.sensitiveStomach` mode).
enum AppetiteState: String, Codable, CaseIterable, Sendable, Identifiable {
    case normal       = "Pretty normal, I get hungry on schedule"
    case quieter      = "Quieter than usual but I can eat"
    case noAppeal     = "Most foods don't appeal right now"
    case nausea       = "Some nausea, small meals only"

    var id: String { rawValue }
}
