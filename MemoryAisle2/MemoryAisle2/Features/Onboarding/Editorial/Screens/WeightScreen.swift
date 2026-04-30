import SwiftUI

/// Screen 07 — Current weight.
struct WeightScreen: View {
    @Binding var profile: OnboardingProfile
    let progress: Double
    let onContinue: () -> Void
    let onSkip: () -> Void

    @State private var draft: String = ""

    var body: some View {
        OnboardingScaffold(progress: progress, onSkip: onSkip) {
            VStack(alignment: .leading, spacing: 0) {
                OnboardingQuestion(lines: [
                    QuestionLine(text: "Where are you"),
                    QuestionLine(text: "now?", italic: true)
                ])
                .padding(.bottom, 8)

                OnboardingHelper(text: "An approximate number is fine. We'll refine it over time.")
                    .padding(.bottom, 22)

                Spacer(minLength: 8)

                OnboardingNumberPill(
                    text: $draft,
                    placeholder: "155",
                    helper: "POUNDS"
                )

                OnboardingPrimaryButton(title: "CONTINUE", action: {
                    profile.weightLbs = Double(draft.trimmingCharacters(in: .whitespacesAndNewlines))
                    onContinue()
                })
                .padding(.top, 14)
            }
        }
        .onAppear {
            draft = profile.weightLbs.map { String(Int($0)) } ?? ""
        }
    }
}
