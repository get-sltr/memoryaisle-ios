import SwiftUI

/// Screen 03 — Open-text "in your own words" goal.
/// Voice button delegates to existing `VoiceManager` (Apple Speech
/// framework, push-to-talk). No new STT path.
struct OpenGoalScreen: View {
    @Binding var profile: OnboardingProfile
    let voice: VoiceManager
    @Binding var isListening: Bool
    let progress: Double
    let onContinue: () -> Void
    let onSkip: () -> Void

    @State private var draft: String = ""

    var body: some View {
        OnboardingScaffold(progress: progress, onSkip: onSkip) {
            VStack(alignment: .leading, spacing: 0) {
                OnboardingQuestion(lines: [
                    QuestionLine(text: "In your own words,"),
                    QuestionLine(text: "what are you hoping for?", italic: true)
                ])
                .padding(.bottom, 8)

                OnboardingHelper(text: "There's no wrong answer. The more honest you are, the better I can help.")
                    .padding(.bottom, 22)

                Spacer(minLength: 8)

                OnboardingTextInput(
                    text: $draft,
                    placeholder: "I want easier meals while I'm on Zepbound... I need help eating enough protein... I'm tired of planning groceries...",
                    voice: voice,
                    isListening: $isListening
                )

                OnboardingPrimaryButton(title: "CONTINUE", action: {
                    let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                    profile.openGoal = trimmed.isEmpty ? nil : trimmed
                    onContinue()
                })
                .padding(.top, 14)
            }
        }
        .onAppear {
            draft = profile.openGoal ?? ""
        }
    }
}
