import OSLog
import SwiftUI

/// Editorial onboarding router. 18 screens, branch-soft routing on Screen 02
/// priorities. Wraps each step in `OnboardingScaffold` with the right
/// progress fraction. Owns a single `VoiceManager` that's threaded into the
/// two open-text screens (03, 10) for hold-to-speak. `onComplete` fires
/// after the timed transition (Screen 18) and hands control back to
/// `OnboardingFlow.completeOnboarding()` which writes the UserProfile and
/// kicks off the WeeklyMealPlanOrchestrator.
struct EditorialOnboardingFlow: View {
    @Binding var profile: OnboardingProfile
    let onComplete: () -> Void

    @State private var step: OnboardingStep = .welcome
    @State private var voice = VoiceManager()
    @State private var isListening: Bool = false

    private let logger = Logger(
        subsystem: "com.sltrdigital.MemoryAisle2",
        category: "Onboarding"
    )

    var body: some View {
        ZStack {
            currentScreen
                .transition(.opacity)
        }
        .task {
            _ = await voice.requestPermissions()
            // Speak the first screen's question so Mira's voice is the
            // first thing the user hears in the editorial flow, matching
            // the legacy MiraOnboardingView behaviour.
            speakQuestion(for: step)
        }
        .onDisappear {
            voice.stopListening()
            voice.stopSpeaking()
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
                voice: voice,
                isListening: $isListening,
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
                voice: voice,
                isListening: $isListening,
                progress: step.progress,
                onContinue: { advance() },
                onSkip: { skip() }
            )
        case .glp1Check:
            GLP1CheckScreenEditorial(
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
        let next = nextStep(after: step)
        logger.log("Onboarding advance: \(self.step.rawValue, privacy: .public) -> \(next.rawValue, privacy: .public)")
        withAnimation(.easeInOut(duration: 0.25)) {
            step = next
        }
        speakQuestion(for: next)
    }

    private func skip() {
        // Skip behaves like advance but logs the user's choice for funnel
        // analytics later. The profile field for that step stays at its
        // default (no user input).
        logger.log("Onboarding skip: \(self.step.rawValue, privacy: .public)")
        advance()
    }

    /// Speaks Mira's prompt for the current step. Centralized here so screens
    /// stay focused on layout and the legacy `MiraOnboardingView.speak`
    /// pattern carries over to the editorial flow without each screen
    /// owning its own VoiceManager call. Empty strings (terminal screens)
    /// short-circuit so we don't trigger an empty utterance.
    private func speakQuestion(for step: OnboardingStep) {
        let text = step.spokenQuestion
        guard !text.isEmpty else { return }
        // Stop any in-flight utterance from a previous screen so the user
        // doesn't hear the old line tail into the new one when they
        // advance quickly.
        voice.stopSpeaking()
        voice.speak(text)
    }

    /// Branch-soft routing. Apple Health sits right after Sex so a successful
    /// connect can prefill the Weight screen from HealthKit's latest reading.
    /// After Movement, the GLP-1 path (Screens 12-15) only runs when
    /// `.glp1Appetite` appears in the user's top priorities. Otherwise we
    /// jump straight to the starting photo. Same branch is honored if the
    /// user reaches Movement without having ranked priorities (skipped
    /// Screen 02) — they're treated as non-GLP-1 path, which is the safer
    /// default.
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
            return profile.priorities.contains(.glp1Appetite) ? .glp1Check : .photo
        case .glp1Check:
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
    case glp1Check
    case medication
    case medStartDate
    case appetite
    case photo
    case ready
    case transition

    /// Per-step progress fraction (matches the mockup's hardcoded widths).
    /// Branch-soft skipping is invisible in the bar — users who skip
    /// Screens 12-15 jump from 66% to 90%, which feels like progress
    /// rather than a gap.
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
        case .glp1Check:        0.72
        case .medication:       0.78
        case .medStartDate:     0.84
        case .appetite:         0.90
        case .photo:            0.96
        case .ready:            1.00
        case .transition:       1.00
        }
    }

    /// What Mira speaks aloud when the user lands on this step. Phrasing is
    /// the natural-sounding (single-line) version of each screen's
    /// typographic question — the layout breaks the line for visual
    /// rhythm, but a single sentence reads better through TTS. Empty
    /// strings on terminal screens (`ready`, `transition`) skip the
    /// utterance.
    var spokenQuestion: String {
        switch self {
        case .welcome:          "Hello. I'm Mira."
        case .priorities:       "What brings you to MemoryAisle?"
        case .openGoal:         "In your own words, what are you hoping for?"
        case .name:             "What should I call you?"
        case .age:              "How old are you?"
        case .sex:              "For protein and calorie math, what was your body assigned at birth?"
        case .appleHealth:      "Want to connect Apple Health so I can read your weight and body composition?"
        case .weight:           "Where are you now? An approximate weight is fine."
        case .goalWeight:       "And where would you like to land?"
        case .foodPreferences:  "Any food preferences I should know?"
        case .movement:         "How do you want me to think about movement?"
        case .glp1Check:        "Are you currently on a GLP-1?"
        case .medication:       "Which medication?"
        case .medStartDate:     "When did you start?"
        case .appetite:         "How is your appetite right now?"
        case .photo:            "Want to set a starting photo? It's optional, you can always change it later."
        case .ready:            ""
        case .transition:       ""
        }
    }
}
