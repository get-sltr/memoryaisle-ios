import SwiftUI

/// Screen 11 — On a GLP-1 right now?
/// "Editorial" suffix to disambiguate from the legacy `GLP1CheckScreen.swift`
/// in the same Features/Onboarding/ tree.
struct GLP1CheckScreenEditorial: View {
    @Binding var profile: OnboardingProfile
    let progress: Double
    let onContinue: () -> Void
    let onSkip: () -> Void

    private let options: [(label: String, isOnGLP1: Bool)] = [
        ("Yes, currently",       true),
        ("Considering it",       false),
        ("I was, not anymore",   false),
        ("No",                   false)
    ]

    var body: some View {
        OnboardingScaffold(progress: progress, onSkip: onSkip) {
            VStack(alignment: .leading, spacing: 0) {
                OnboardingQuestion(lines: [
                    QuestionLine(text: "Are you"),
                    QuestionLine(text: "currently on a GLP-1?", italic: true)
                ])
                .padding(.bottom, 8)

                OnboardingHelper(text: "If yes, I'll tune meal timing, protein, and side-effect support to your dose schedule.")
                    .padding(.bottom, 22)

                Spacer(minLength: 8)

                VStack(spacing: 8) {
                    ForEach(options, id: \.label) { option in
                        OnboardingChoice(title: option.label, action: {
                            profile.isOnGLP1 = option.isOnGLP1
                            if !option.isOnGLP1 {
                                profile.medication = nil
                                profile.modality = nil
                            }
                            onContinue()
                        })
                    }
                }
            }
        }
    }
}
