import SwiftUI
import SwiftData

struct OnboardingFlow: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @State private var showWelcome = true
    @State private var showOnboarding = false
    @State private var profile = OnboardingProfile()

    var body: some View {
        ZStack {
            if showWelcome {
                welcomeScreen
                    .transition(.scale(scale: 0.01).combined(with: .opacity))
                    .zIndex(1)
            }

            if showOnboarding {
                MiraOnboardingView(
                    profile: $profile,
                    onComplete: { completeOnboarding() }
                )
                .transition(.opacity)
            }
        }
        .themeBackground()
    }

    // MARK: - Welcome Screen

    private var welcomeScreen: some View {
        VStack(spacing: 0) {
            Spacer()

            OnboardingLogo(size: 220)
                .shadow(color: Color.violet.opacity(0.4), radius: 40, y: 10)

            Text("Welcome to")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Theme.Text.secondary(for: scheme))
                .padding(.top, 32)

            Text("MemoryAisle")
                .font(.system(size: 34, weight: .light, design: .serif))
                .foregroundStyle(Theme.Text.primary)
                .tracking(1)
                .padding(.top, 4)

            Text("Lose fat without losing muscle.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.Text.tertiary(for: scheme))
                .padding(.top, 12)

            Spacer()

            Button {
                HapticManager.medium()
                withAnimation(.easeIn(duration: 0.6)) {
                    showWelcome = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(Theme.Motion.spring) {
                        showOnboarding = true
                    }
                }
            } label: {
                Text("Enter")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.Text.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        Capsule().fill(Color.violet.opacity(0.25))
                    )
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 60)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background(for: scheme))
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
    var worries: [Worry] = []
    var trainingLevel: TrainingLevel = .none
    var dietaryRestrictions: [DietaryRestriction] = []
}
