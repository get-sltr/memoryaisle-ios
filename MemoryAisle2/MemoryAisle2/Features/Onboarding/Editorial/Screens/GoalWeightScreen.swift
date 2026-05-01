import SwiftUI

/// Screen 08 — Goal weight (with no-goal option).
struct GoalWeightScreen: View {
    @Binding var profile: OnboardingProfile
    let progress: Double
    let onContinue: () -> Void
    let onSkip: () -> Void

    @State private var draft: String = ""

    var body: some View {
        OnboardingScaffold(progress: progress, onSkip: onSkip) {
            VStack(alignment: .leading, spacing: 0) {
                OnboardingQuestion(lines: [
                    QuestionLine(text: "And where would you like to"),
                    QuestionLine(text: "land?", italic: true)
                ])
                .padding(.bottom, 8)

                OnboardingHelper(text: "If you don't have a number in mind, that's fine. We can shape this together over time.")
                    .padding(.bottom, 22)

                Spacer(minLength: 8)

                OnboardingNumberPill(text: $draft, placeholder: "135", helper: "POUNDS")

                OnboardingPrimaryButton(title: "CONTINUE", action: {
                    profile.goalWeightLbs = Double(draft.trimmingCharacters(in: .whitespacesAndNewlines))
                    onContinue()
                })
                .padding(.top, 14)

                OnboardingSecondaryButton(title: "I DON'T HAVE A GOAL YET", action: {
                    profile.goalWeightLbs = nil
                    onContinue()
                })
                .padding(.top, 8)
            }
        }
        .onAppear {
            draft = profile.goalWeightLbs.map { String(Int($0)) } ?? ""
        }
    }
}
