import SwiftUI

/// Screen 01 — Welcome / Mira intro.
struct OnboardingWelcomeScreen: View {
    let progress: Double
    let onContinue: () -> Void

    var body: some View {
        OnboardingScaffold(progress: progress, onSkip: nil) {
            VStack(alignment: .leading, spacing: 0) {
                OnboardingMiraMark()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 22)

                OnboardingQuestion(
                    lines: [
                        QuestionLine(text: "Hello."),
                        QuestionLine(text: "I'm Mira.", italic: true)
                    ],
                    size: 28
                )
                .padding(.bottom, 8)

                OnboardingHelper(text: "I'll help you eat well, plan meals, and stay consistent. The next few minutes are about you. Take your time.")

                Spacer(minLength: 24)

                OnboardingPrimaryButton(title: "BEGIN", trailingArrow: true, action: onContinue)
            }
        }
    }
}
