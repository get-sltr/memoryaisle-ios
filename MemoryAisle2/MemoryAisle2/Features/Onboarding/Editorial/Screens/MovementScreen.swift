import SwiftUI

/// Screen 10 — Movement (reframed from "exercise").
/// Includes the deliberate "nutrition only" option per the schema change.
/// Optional open-text note via `VoiceManager` push-to-talk.
struct MovementScreen: View {
    @Binding var profile: OnboardingProfile
    let voice: VoiceManager
    @Binding var isListening: Bool
    let progress: Double
    let onContinue: () -> Void
    let onSkip: () -> Void

    @State private var draftNote: String = ""

    /// Order matches the mockup: lifts, cardio, sometimes (walks/daily life),
    /// nutritionOnly. `.none` is omitted from the editorial UI — users who
    /// don't pick any option but tap Continue keep their default `.none`.
    private let displayOrder: [TrainingLevel] = [.lifts, .cardio, .sometimes, .nutritionOnly]

    var body: some View {
        OnboardingScaffold(progress: progress, onSkip: onSkip) {
            VStack(alignment: .leading, spacing: 0) {
                OnboardingQuestion(lines: [
                    QuestionLine(text: "How do you want me to think about"),
                    QuestionLine(text: "movement?", italic: true)
                ])
                .padding(.bottom, 8)

                OnboardingHelper(text: "Some people lose weight through nutrition alone. That's a real path. I'll match yours.")
                    .padding(.bottom, 18)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 8) {
                        ForEach(displayOrder, id: \.self) { level in
                            OnboardingChoice(
                                title: level.displayName,
                                isSelected: profile.trainingLevel == level,
                                action: {
                                    HapticManager.light()
                                    profile.trainingLevel = level
                                }
                            )
                        }

                        OnboardingTextInput(
                            text: $draftNote,
                            placeholder: "Anything else? Tell Mira about your routine, injuries, or what works for you...",
                            minHeight: 80,
                            voice: voice,
                            isListening: $isListening
                        )
                        .padding(.top, 4)
                    }
                }
                .frame(maxHeight: .infinity)

                OnboardingPrimaryButton(title: "CONTINUE", action: {
                    let trimmed = draftNote.trimmingCharacters(in: .whitespacesAndNewlines)
                    profile.movementNote = trimmed.isEmpty ? nil : trimmed
                    onContinue()
                })
                .padding(.top, 14)
            }
        }
        .onAppear {
            draftNote = profile.movementNote ?? ""
        }
    }
}
