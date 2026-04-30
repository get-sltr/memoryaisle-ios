import SwiftUI

/// Screen 06 — Biological sex (warmer framing). Auto-advances on tap.
struct SexScreen: View {
    @Binding var profile: OnboardingProfile
    let progress: Double
    let onContinue: () -> Void
    let onSkip: () -> Void

    var body: some View {
        OnboardingScaffold(progress: progress, onSkip: onSkip) {
            VStack(alignment: .leading, spacing: 0) {
                OnboardingQuestion(lines: [
                    QuestionLine(text: "For protein and calorie math,"),
                    QuestionLine(text: "what was your body assigned at birth?", italic: true)
                ])
                .padding(.bottom, 8)

                OnboardingHelper(text: "Used only for nutrition calculations. You can identify however you want everywhere else.")
                    .padding(.bottom, 22)

                Spacer(minLength: 8)

                VStack(spacing: 8) {
                    ForEach(BiologicalSex.allCases, id: \.self) { sex in
                        OnboardingChoice(
                            title: sex.rawValue,
                            isSelected: profile.sex == sex,
                            action: {
                                profile.sex = sex
                                onContinue()
                            }
                        )
                    }
                }
            }
        }
    }
}
