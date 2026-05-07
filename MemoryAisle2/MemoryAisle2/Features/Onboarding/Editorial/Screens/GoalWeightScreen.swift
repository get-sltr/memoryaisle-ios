import SwiftUI

/// Screen 08 — Goal weight (with no-goal option).
struct GoalWeightScreen: View {
    @Binding var profile: OnboardingProfile
    let progress: Double
    let onContinue: () -> Void
    let onSkip: () -> Void

    @Environment(AppState.self) private var appState
    @State private var draft: String = ""

    private var isMetric: Bool { appState.unitSystem == .metric }
    private var helperLabel: String { isMetric ? "KILOGRAMS" : "POUNDS" }
    private var placeholder: String { isMetric ? "61" : "135" }

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

                OnboardingNumberPill(text: $draft, placeholder: placeholder, helper: helperLabel)

                OnboardingPrimaryButton(title: "CONTINUE", action: {
                    let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                    if let entered = Double(trimmed) {
                        profile.goalWeightLbs = WeightFormat.toCanonical(entered, from: appState.unitSystem)
                    } else {
                        profile.goalWeightLbs = nil
                    }
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
            draft = profile.goalWeightLbs
                .map { WeightFormat.displayValue($0, system: appState.unitSystem) }
                .map(String.init) ?? ""
        }
    }
}
