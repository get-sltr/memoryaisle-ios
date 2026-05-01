import SwiftUI

/// Screen 04 — Name.
struct NameScreen: View {
    @Binding var profile: OnboardingProfile
    let progress: Double
    let onContinue: () -> Void
    let onSkip: () -> Void

    @State private var draft: String = ""

    var body: some View {
        OnboardingScaffold(progress: progress, onSkip: onSkip) {
            VStack(alignment: .leading, spacing: 0) {
                OnboardingQuestion(lines: [
                    QuestionLine(text: "What should I"),
                    QuestionLine(text: "call you?", italic: true)
                ])
                .padding(.bottom, 8)

                OnboardingHelper(text: "Whatever you'd like, first name, nickname, or however you introduce yourself.")
                    .padding(.bottom, 22)

                Spacer(minLength: 8)

                OnboardingNumberPill(
                    text: $draft,
                    placeholder: "Type your name...",
                    helper: "YOU CAN CHANGE THIS ANYTIME IN SETTINGS",
                    keyboardType: .default
                )

                OnboardingPrimaryButton(title: "CONTINUE", action: {
                    profile.name = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                    onContinue()
                })
                .padding(.top, 14)
            }
        }
        .onAppear {
            draft = profile.name
        }
    }
}
