import OSLog
import SwiftUI

/// Editorial onboarding router. 18 screens, branch-soft routing on Screen 02
/// priorities. Wraps each step in `OnboardingScaffold` with the right
/// progress fraction. Free-text screens (03, 10) lean on the iOS system
/// keyboard's dictation mic — no in-app STT layer. `onComplete` fires
/// after the timed transition (Screen 18) and hands control back to
/// `OnboardingFlow.completeOnboarding()` which writes the UserProfile and
/// kicks off the WeeklyMealPlanOrchestrator.
struct EditorialOnboardingFlow: View {
    @Binding var profile: OnboardingProfile
    let onComplete: () -> Void

    @State private var step: OnboardingStep = .welcome

    private let logger = Logger(
        subsystem: "com.sltrdigital.MemoryAisle2",
        category: "Onboarding"
    )

    var body: some View {
        ZStack {
            currentScreen
                .transition(.opacity)
        }
    }

    // MARK: - Current screen dispatch

    @ViewBuilder
    private var currentScreen: some View {
        switch step {
        case .welcome:
            OnboardingWelcomeScreen(progress: step.progress, onContinue: { advance() })
        case .priorities:
            PrioritiesScreen(
                profile: $profile,
                progress: step.progress,
                onContinue: { advance() },
                onSkip: { skip() }
            )
        case .openGoal:
            OpenGoalScreen(
                profile: $profile,
                progress: step.progress,
                onContinue: { advance() },
                onSkip: { skip() }
            )
        case .name:
            NameScreen(
                profile: $profile,
                progress: step.progress,
                onContinue: { advance() },
                onSkip: { skip() }
            )
        case .age:
            AgeScreen(
                profile: $profile,
                progress: step.progress,
                onContinue: { advance() },
                onSkip: { skip() }
            )
        case .sex:
            SexScreen(
                profile: $profile,
                progress: step.progress,
                onContinue: { advance() },
                onSkip: { skip() }
            )
        case .weight:
            WeightScreen(
                profile: $profile,
                progress: step.progress,
                onContinue: { advance() },
                onSkip: { skip() }
            )
        case .goalWeight:
            GoalWeightScreen(
                profile: $profile,
                progress: step.progress,
                onContinue: { advance() },
                onSkip: { skip() }
            )
        case .foodPreferences:
            FoodPreferencesScreen(
                profile: $profile,
                progress: step.progress,
                onContinue: { advance() },
                onSkip: { skip() }
            )
        case .movement:
            MovementScreen(
                profile: $profile,
                progress: step.progress,
                onContinue: { advance() },
                onSkip: { skip() }
            )
        case .medication:
            MedicationScreenEditorial(
                profile: $profile,
                progress: step.progress,
                onContinue: { advance() },
                onSkip: { skip() }
            )
        case .medStartDate:
            MedicationStartScreenEditorial(
                profile: $profile,
                progress: step.progress,
                onContinue: { advance() },
                onSkip: { skip() }
            )
        case .appetite:
            AppetiteScreen(
                profile: $profile,
                progress: step.progress,
                onContinue: { advance() },
                onSkip: { skip() }
            )
        case .appleHealth:
            AppleHealthScreenEditorial(
                profile: $profile,
                progress: step.progress,
                onContinue: { advance() },
                onSkip: { skip() }
            )
        case .photo:
            PhotoScreenEditorial(
                profile: $profile,
                progress: step.progress,
                onContinue: { advance() },
                onSkip: { skip() }
            )
        case .ready:
            ReadyScreenEditorial(
                profile: $profile,
                progress: step.progress,
                onContinue: { advance() }
            )
        case .transition:
            PersonalizationTransitionScreen(
                progress: step.progress,
                onComplete: onComplete
            )
        }
    }

    // MARK: - Routing

    private func advance() {
        // Priority answer is the source of truth for "on a GLP-1?". The
        // separate glp1Check screen used to ask again — dropped after user
        // pointed out the duplication.
        if step == .priorities {
            profile.isOnGLP1 = profile.priorities.contains(.glp1Appetite)
        }

        let next = nextStep(after: step)
        logger.log("Onboarding advance: \(self.step.rawValue, privacy: .public) -> \(next.rawValue, privacy: .public)")
        withAnimation(.easeInOut(duration: 0.25)) {
            step = next
        }
    }

    private func skip() {
        // Skip behaves like advance but logs the user's choice for funnel
        // analytics later. The profile field for that step stays at its
        // default (no user input).
        logger.log("Onboarding skip: \(self.step.rawValue, privacy: .public)")
        advance()
    }

    /// Branch-soft routing. Apple Health sits right after Sex so a successful
    /// connect can prefill the Weight screen from HealthKit's latest reading.
    /// After Movement, the GLP-1 path (medication / start date / appetite)
    /// only runs when the user picked `.glp1Appetite` in priorities;
    /// otherwise we jump straight to the starting photo. The legacy
    /// `glp1Check` step was redundant with the priority answer and got
    /// dropped — `advance()` mirrors the priority into `profile.isOnGLP1`.
    private func nextStep(after current: OnboardingStep) -> OnboardingStep {
        switch current {
        case .welcome:          return .priorities
        case .priorities:       return .openGoal
        case .openGoal:         return .name
        case .name:             return .age
        case .age:              return .sex
        case .sex:              return .appleHealth
        case .appleHealth:      return .weight
        case .weight:           return .goalWeight
        case .goalWeight:       return .foodPreferences
        case .foodPreferences:  return .movement
        case .movement:
            return profile.isOnGLP1 ? .medication : .photo
        case .medication:       return .medStartDate
        case .medStartDate:     return .appetite
        case .appetite:         return .photo
        case .photo:            return .ready
        case .ready:            return .transition
        case .transition:       return .transition  // terminal — onComplete fires
        }
    }
}

// MARK: - Step enum

/// Editorial onboarding step. Numbered 1-18 to match the design mockup.
/// `progress` returns the fill fraction shown in the masthead bar.
enum OnboardingStep: Int, CaseIterable, Sendable {
    case welcome = 1
    case priorities
    case openGoal
    case name
    case age
    case sex
    case appleHealth
    case weight
    case goalWeight
    case foodPreferences
    case movement
    case medication
    case medStartDate
    case appetite
    case photo
    case ready
    case transition

    /// Per-step progress fraction. Branch-soft skipping is invisible in the
    /// bar — users who skip the medication path jump straight to photo,
    /// which feels like progress rather than a gap.
    var progress: Double {
        switch self {
        case .welcome:          0.06
        case .priorities:       0.12
        case .openGoal:         0.18
        case .name:             0.24
        case .age:              0.30
        case .sex:              0.36
        case .appleHealth:      0.42
        case .weight:           0.48
        case .goalWeight:       0.54
        case .foodPreferences:  0.60
        case .movement:         0.66
        case .medication:       0.76
        case .medStartDate:     0.83
        case .appetite:         0.90
        case .photo:            0.96
        case .ready:            1.00
        case .transition:       1.00
        }
    }

}
