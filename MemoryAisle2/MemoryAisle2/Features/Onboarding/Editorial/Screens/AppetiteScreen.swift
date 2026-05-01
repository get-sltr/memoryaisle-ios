import SwiftUI

/// Screen 14 — How is appetite right now. Auto-advances on tap. Maps to
/// `AppetiteState`, which the completion logic reads to bias `ProductMode`
/// toward `.sensitiveStomach` when the answer indicates significant
/// suppression (`.noAppeal` or `.nausea`).
struct AppetiteScreen: View {
    @Binding var profile: OnboardingProfile
    let progress: Double
    let onContinue: () -> Void
    let onSkip: () -> Void

    var body: some View {
        OnboardingScaffold(progress: progress, onSkip: onSkip) {
            VStack(alignment: .leading, spacing: 0) {
                OnboardingQuestion(lines: [
                    QuestionLine(text: "How is your"),
                    QuestionLine(text: "appetite right now?", italic: true)
                ])
                .padding(.bottom, 8)

                OnboardingHelper(text: "Honest answer. I'll match meal sizes and timing to where you actually are today.")
                    .padding(.bottom, 22)

                Spacer(minLength: 8)

                VStack(spacing: 8) {
                    ForEach(AppetiteState.allCases) { state in
                        OnboardingChoice(
                            title: state.rawValue,
                            isSelected: profile.appetiteState == state,
                            action: {
                                profile.appetiteState = state
                                if state == .nausea {
                                    if !profile.worries.contains(.nausea) {
                                        profile.worries.append(.nausea)
                                    }
                                }
                                onContinue()
                            }
                        )
                    }
                }
            }
        }
    }
}
