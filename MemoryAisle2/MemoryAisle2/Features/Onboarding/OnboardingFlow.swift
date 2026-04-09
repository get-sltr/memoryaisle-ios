import SwiftUI
import SwiftData

struct OnboardingFlow: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @State private var step: OnboardingStep = .welcome
    @State private var showWelcome = true
    @State private var profile = OnboardingProfile()

    var body: some View {
        ZStack {
            Color.clear

            if showWelcome {
                welcomeScreen
                    .transition(.scale(scale: 0.01).combined(with: .opacity))
                    .zIndex(1)
            }

            VStack(spacing: 0) {
                // Top bar: back button + progress
                if step != .intro && step != .welcome {
                    HStack {
                        Button {
                            HapticManager.light()
                            withAnimation(.easeOut(duration: 0.25)) {
                                goBack()
                            }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Theme.Text.secondary(for: scheme))
                                .frame(width: 44, height: 44)
                        }

                        Spacer()

                        if step != .ready {
                            progressDots
                        }

                        Spacer()

                        Color.clear.frame(width: 44, height: 44)
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 4)
                }

                // Content
                Group {
                    switch step {
                    case .welcome:
                        Color.clear
                    case .intro:
                        MiraIntroScreen(onContinue: { step = .glp1Check })
                    case .glp1Check:
                        GLP1CheckScreen(
                            onYes: { step = .medication },
                            onNo: {
                                profile.isOnGLP1 = false
                                profile.medication = nil
                                profile.modality = nil
                                profile.doseAmount = nil
                                profile.injectionDay = nil
                                profile.pillTime = nil
                                step = .bodyStats
                            }
                        )
                    case .medication:
                        MedicationSelectScreen(
                            selection: $profile.medication,
                            onContinue: { step = .doseTiming }
                        )
                    case .doseTiming:
                        DoseTimingScreen(
                            profile: $profile,
                            onContinue: { step = .bodyStats }
                        )
                    case .bodyStats:
                        BodyStatsScreen(
                            profile: $profile,
                            onContinue: { step = .worries }
                        )
                    case .worries:
                        WorriesScreen(
                            selected: $profile.worries,
                            onContinue: { step = .training }
                        )
                    case .training:
                        TrainingScreen(
                            selection: $profile.trainingLevel,
                            onContinue: { step = .dietary }
                        )
                    case .dietary:
                        DietaryScreen(
                            selected: $profile.dietaryRestrictions,
                            onContinue: { step = .ready }
                        )
                    case .ready:
                        MiraReadyScreen(
                            profile: profile,
                            onComplete: { completeOnboarding() }
                        )
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .animation(Theme.Motion.spring, value: step)
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
                        step = .intro
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
                    .overlay(
                        Capsule().stroke(Color.violet.opacity(0.4), lineWidth: 0.5)
                    )
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 60)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background(for: scheme))
    }

    // MARK: - Progress Dots

    private var progressDots: some View {
        HStack(spacing: 6) {
            ForEach(OnboardingStep.allCases.filter { $0 != .welcome && $0 != .intro && $0 != .ready }, id: \.self) { s in
                Capsule()
                    .fill(s.rawValue <= step.rawValue ? Color.violet : Theme.Surface.strong(for: scheme))
                    .frame(width: s == step ? 20 : 6, height: 4)
                    .animation(.easeInOut(duration: 0.25), value: step)
            }
        }
    }

    // MARK: - Navigation

    private func goBack() {
        switch step {
        case .welcome: break
        case .intro: break
        case .glp1Check: step = .intro
        case .medication: step = .glp1Check
        case .doseTiming: step = .medication
        case .bodyStats: step = profile.isOnGLP1 ? .doseTiming : .glp1Check
        case .worries: step = .bodyStats
        case .training: step = .worries
        case .dietary: step = .training
        case .ready: step = .dietary
        }
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
        // If we have actual weight, calculate from lean mass estimate
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

        // Fallback defaults if no weight provided
        switch profile.trainingLevel {
        case .lifts: return 150
        case .cardio: return 130
        case .sometimes: return 120
        case .none: return 100
        }
    }
}

// MARK: - Step Enum

enum OnboardingStep: Int, CaseIterable {
    case welcome = -1
    case intro = 0
    case glp1Check = 1
    case medication = 2
    case doseTiming = 3
    case bodyStats = 4
    case worries = 5
    case training = 6
    case dietary = 7
    case ready = 8
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
