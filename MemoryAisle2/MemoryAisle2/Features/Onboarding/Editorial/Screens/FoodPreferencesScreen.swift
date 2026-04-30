import SwiftUI

/// Screen 09 — Combined food preferences.
/// Two sections in one screen: dietary style chips + avoid chips.
/// "Style" maps loosely; "Avoid" maps to existing `DietaryRestriction`
/// enum cases when those overlap (Dairy → .dairyFree, Gluten → .glutenFree,
/// etc.). Style chips that don't have a 1:1 enum mapping (Mediterranean,
/// Balanced) are persisted as informational notes appended to dietary
/// restrictions via display name only — Mira treats them as preference
/// signals, not hard restrictions.
struct FoodPreferencesScreen: View {
    @Binding var profile: OnboardingProfile
    let progress: Double
    let onContinue: () -> Void
    let onSkip: () -> Void

    private let styleChips = ["High protein", "Mediterranean", "Vegetarian", "Vegan", "Low carb", "Balanced"]
    private let avoidChips = ["Pork", "Beef", "Dairy", "Gluten", "Shellfish", "Nuts", "Spicy", "Fried"]

    @State private var selectedStyles: Set<String> = []
    @State private var selectedAvoids: Set<String> = []

    var body: some View {
        OnboardingScaffold(progress: progress, onSkip: onSkip) {
            VStack(alignment: .leading, spacing: 0) {
                OnboardingQuestion(lines: [
                    QuestionLine(text: "Any food preferences"),
                    QuestionLine(text: "I should know?", italic: true)
                ])
                .padding(.bottom, 8)

                OnboardingHelper(text: "Tell me what you eat and what to avoid. Change anytime in settings.")
                    .padding(.bottom, 18)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 10) {
                            OnboardingSectionLabel(text: "I USUALLY EAT")
                            OnboardingChipRow(
                                chips: styleChips,
                                selection: selectedStyles,
                                onToggle: { toggle($0, in: &selectedStyles) }
                            )
                        }
                        VStack(alignment: .leading, spacing: 10) {
                            OnboardingSectionLabel(text: "LEAVE ALONE / AVOID")
                            OnboardingChipRow(
                                chips: avoidChips,
                                selection: selectedAvoids,
                                onToggle: { toggle($0, in: &selectedAvoids) }
                            )
                        }
                    }
                }
                .frame(maxHeight: .infinity)

                OnboardingPrimaryButton(title: "CONTINUE", action: {
                    persist()
                    onContinue()
                })
                .padding(.top, 16)
            }
        }
    }

    private func toggle(_ value: String, in set: inout Set<String>) {
        HapticManager.light()
        if set.contains(value) {
            set.remove(value)
        } else {
            set.insert(value)
        }
    }

    /// Maps the screen's chip labels to existing `DietaryRestriction` cases
    /// where possible. Anything without a clean mapping is dropped (we keep
    /// the model surface tight rather than inventing case labels just for
    /// onboarding chips).
    private func persist() {
        var restrictions: Set<DietaryRestriction> = []

        let styleMap: [String: DietaryRestriction] = [
            "Vegetarian": .vegetarian,
            "Vegan": .vegan,
            "Mediterranean": .mediterranean,
            "Low carb": .keto
        ]
        let avoidMap: [String: DietaryRestriction] = [
            "Dairy": .dairyFree,
            "Gluten": .glutenFree,
            "Shellfish": .shellfishAllergy,
            "Nuts": .nutAllergy
        ]
        for s in selectedStyles { if let r = styleMap[s] { restrictions.insert(r) } }
        for a in selectedAvoids { if let r = avoidMap[a] { restrictions.insert(r) } }
        profile.dietaryRestrictions = Array(restrictions)
    }
}
