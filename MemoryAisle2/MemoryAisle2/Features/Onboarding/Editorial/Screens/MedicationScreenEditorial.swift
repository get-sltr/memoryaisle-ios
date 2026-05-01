import SwiftUI

/// Screen 12 — Which medication. Maps display labels to existing
/// `Medication` enum cases.
struct MedicationScreenEditorial: View {
    @Binding var profile: OnboardingProfile
    let progress: Double
    let onContinue: () -> Void
    let onSkip: () -> Void

    private let options: [(name: String, ingredient: String, medication: Medication)] = [
        ("Ozempic",     "semaglutide",        .ozempic),
        ("Wegovy",      "semaglutide",        .wegovy),
        ("Rybelsus",    "oral semaglutide",   .rybelsus),
        ("Mounjaro",    "tirzepatide",        .mounjaro),
        ("Zepbound",    "tirzepatide",        .zepbound),
        ("Saxenda",     "liraglutide",        .other),
        ("Compounded",  "specify",            .compoundedSemaglutide),
        ("Other / not listed", "",            .other)
    ]

    var body: some View {
        OnboardingScaffold(progress: progress, onSkip: onSkip) {
            VStack(alignment: .leading, spacing: 0) {
                OnboardingQuestion(lines: [
                    QuestionLine(text: "Which"),
                    QuestionLine(text: "medication?", italic: true)
                ])
                .padding(.bottom, 8)

                OnboardingHelper(text: "Same active ingredient, sometimes different brand. Pick what's on your prescription.")
                    .padding(.bottom, 18)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 6) {
                        ForEach(options, id: \.name) { option in
                            OnboardingChoice(
                                title: option.name,
                                subtitle: option.ingredient.isEmpty ? nil : option.ingredient,
                                isSelected: profile.medication == option.medication,
                                action: {
                                    profile.medication = option.medication
                                    profile.modality = (option.ingredient == "oral semaglutide")
                                        ? .oralWithFasting
                                        : .injectable
                                    onContinue()
                                }
                            )
                        }
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
    }
}
