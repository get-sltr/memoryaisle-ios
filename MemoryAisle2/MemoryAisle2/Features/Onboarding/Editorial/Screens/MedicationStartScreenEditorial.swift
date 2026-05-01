import SwiftUI

/// Screen 13 — When did you start. Wheel date picker, defaults to one month
/// ago (sensible default for "recently started" users). Persists to
/// `profile.medicationStartDate` and the legacy UserDefaults key the
/// dashboard's cycle-day calculation reads.
struct MedicationStartScreenEditorial: View {
    @Binding var profile: OnboardingProfile
    let progress: Double
    let onContinue: () -> Void
    let onSkip: () -> Void

    @State private var selected: Date = Calendar.current.date(
        byAdding: .month,
        value: -1,
        to: Date()
    ) ?? Date()

    var body: some View {
        OnboardingScaffold(progress: progress, onSkip: onSkip) {
            VStack(alignment: .leading, spacing: 0) {
                OnboardingQuestion(lines: [
                    QuestionLine(text: "When did you"),
                    QuestionLine(text: "start?", italic: true)
                ])
                .padding(.bottom, 8)

                OnboardingHelper(text: "Roughly is fine. Helps me understand where you are in the journey.")
                    .padding(.bottom, 22)

                Spacer(minLength: 8)

                DatePicker(
                    "",
                    selection: $selected,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .colorScheme(.dark)
                .frame(maxHeight: 180)
                .frame(maxWidth: .infinity)

                OnboardingPrimaryButton(title: "CONTINUE", action: {
                    profile.medicationStartDate = selected
                    UserDefaults.standard.set(selected, forKey: "medicationStartDate")
                    onContinue()
                })
                .padding(.top, 14)

                OnboardingSecondaryButton(title: "I DON'T REMEMBER", action: {
                    profile.medicationStartDate = Date()
                    UserDefaults.standard.set(Date(), forKey: "medicationStartDate")
                    onContinue()
                })
                .padding(.top, 8)
            }
        }
        .onAppear {
            if let existing = profile.medicationStartDate {
                selected = existing
            }
        }
    }
}
