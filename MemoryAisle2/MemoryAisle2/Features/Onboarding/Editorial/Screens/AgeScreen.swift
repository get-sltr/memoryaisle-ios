import SwiftUI

/// Screen 05 — Age.
struct AgeScreen: View {
    @Binding var profile: OnboardingProfile
    let progress: Double
    let onContinue: () -> Void
    let onSkip: () -> Void

    @State private var draft: String = ""

    var body: some View {
        OnboardingScaffold(progress: progress, onSkip: onSkip) {
            VStack(alignment: .leading, spacing: 0) {
                OnboardingQuestion(lines: [
                    QuestionLine(text: "How"),
                    QuestionLine(text: "old are you?", italic: true)
                ])
                .padding(.bottom, 8)

                OnboardingHelper(text: "Helps me calibrate calorie and protein recommendations to your body's actual needs.")
                    .padding(.bottom, 22)

                Spacer(minLength: 8)

                OnboardingNumberPill(text: $draft, placeholder: "34", helper: "YEARS")

                OnboardingPrimaryButton(title: "CONTINUE", action: {
                    profile.age = Int(draft.trimmingCharacters(in: .whitespacesAndNewlines))
                    onContinue()
                })
                .padding(.top, 14)
            }
        }
        .onAppear {
            draft = profile.age.map { "\($0)" } ?? ""
        }
    }
}
