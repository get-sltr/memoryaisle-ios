import SwiftUI
import SwiftData

struct OnboardingFlow: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @State private var step: OnboardingStep = .intro
    @State private var profile = OnboardingProfile()

    var body: some View {
        ZStack {
            Color.indigoBlack.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar: back button + progress
                if step != .intro {
                    HStack {
                        Button {
                            HapticManager.light()
                            withAnimation(.easeOut(duration: 0.25)) {
                                goBack()
                            }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.white.opacity(0.5))
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
                    case .intro:
                        MiraIntroScreen(onContinue: { step = .glp1Check })
                    case .glp1Check:
                        GLP1CheckScreen(
                            onYes: { step = .medication },
                            onNo: {
                                profile.isOnGLP1 = false
                                step = .worries
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
    }

    // MARK: - Progress Dots

    private var progressDots: some View {
        HStack(spacing: 6) {
            ForEach(OnboardingStep.allCases.filter { $0 != .intro && $0 != .ready }, id: \.self) { s in
                Capsule()
                    .fill(s.rawValue <= step.rawValue ? Color.violet : Color.white.opacity(0.1))
                    .frame(width: s == step ? 20 : 6, height: 4)
                    .animation(.easeInOut(duration: 0.25), value: step)
            }
        }
    }

    // MARK: - Navigation

    private func goBack() {
        switch step {
        case .intro: break
        case .glp1Check: step = .intro
        case .medication: step = .glp1Check
        case .doseTiming: step = .medication
        case .worries: step = profile.isOnGLP1 ? .doseTiming : .glp1Check
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

        modelContext.insert(user)
        appState.hasCompletedOnboarding = true
    }

    private func deriveMode() -> ProductMode {
        if profile.worries.contains(.nausea) { return .sensitiveStomach }
        if profile.trainingLevel == .lifts { return .musclePreservation }
        return .everyday
    }

    private func deriveProteinTarget() -> Int {
        switch profile.trainingLevel {
        case .lifts: 140
        case .cardio: 120
        case .sometimes: 110
        case .none: 100
        }
    }
}

// MARK: - Step Enum

enum OnboardingStep: Int, CaseIterable {
    case intro = 0
    case glp1Check = 1
    case medication = 2
    case doseTiming = 3
    case worries = 4
    case training = 5
    case dietary = 6
    case ready = 7
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
    var worries: [Worry] = []
    var trainingLevel: TrainingLevel = .none
    var dietaryRestrictions: [DietaryRestriction] = []
}
