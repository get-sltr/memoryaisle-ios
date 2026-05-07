import SwiftUI

/// Screen 08 — Current weight. Pre-fills from `profile.weightLbs` if Apple
/// Health (Screen 07) authorized and returned a recent reading.
struct WeightScreen: View {
    @Binding var profile: OnboardingProfile
    let progress: Double
    let onContinue: () -> Void
    let onSkip: () -> Void

    @Environment(AppState.self) private var appState
    @State private var draft: String = ""

    private var isMetric: Bool { appState.unitSystem == .metric }
    private var helperLabel: String { isMetric ? "KILOGRAMS" : "POUNDS" }
    private var placeholder: String { isMetric ? "70" : "155" }

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
                    placeholder: placeholder,
                    helper: helperLabel
                )

                OnboardingPrimaryButton(title: "CONTINUE", action: {
                    let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                    if let entered = Double(trimmed) {
                        profile.weightLbs = WeightFormat.toCanonical(entered, from: appState.unitSystem)
                    } else {
                        profile.weightLbs = nil
                    }
                    onContinue()
                })
                .padding(.top, 14)
            }
        }
        .onAppear {
            draft = profile.weightLbs
                .map { WeightFormat.displayValue($0, system: appState.unitSystem) }
                .map(String.init) ?? ""
        }
    }
}
