import SwiftUI
import SwiftData

struct OnboardingFlow: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @State private var showOnboarding = true
    @State private var profile = OnboardingProfile()

    var body: some View {
        ZStack {
            if showOnboarding {
                MiraOnboardingView(
                    profile: $profile,
                    onComplete: { completeOnboarding() }
                )
                .transition(.opacity)
            }
        }
        .section(.home)
        .themeBackground()
    }

    // MARK: - Complete

    private func completeOnboarding() {
        let user = UserProfile(
            medication: profile.medication,
            medicationModality: profile.modality,
            productMode: deriveMode(),
            proteinTargetGrams: deriveProteinTarget()
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
    }

    private func deriveMode() -> ProductMode {
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
            case .lifts: 1.2
            case .cardio: 1.0
            case .sometimes: 0.9
            case .none: 0.8
            }
            return Int(leanMass * gramsPerLb)
        }

        switch profile.trainingLevel {
        case .lifts: return 150
        case .cardio: return 130
        case .sometimes: return 120
        case .none: return 100
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
}
