import SwiftUI

/// Chip multi-select for `DietaryRestriction`. Two-column adaptive layout,
/// editorial styling (hairline border, caps label, fill on selected).
/// The binding writes back through SwiftData when the parent view binds it
/// to a `@Model` property like `profile.dietaryRestrictions`.
struct AllergyChipGrid: View {
    @Binding var selected: [DietaryRestriction]
    var options: [DietaryRestriction] = DietaryRestriction.allCases

    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(options, id: \.self) { option in
                chip(option)
            }
        }
    }

    private func chip(_ option: DietaryRestriction) -> some View {
        let isOn = selected.contains(option)
        return Button {
            HapticManager.light()
            toggle(option)
        } label: {
            Text(option.rawValue)
                .font(Theme.Editorial.Typography.caps(10, weight: .semibold))
                .tracking(1.6)
                .textCase(.uppercase)
                .foregroundStyle(Theme.Editorial.onSurface)
                .frame(maxWidth: .infinity, minHeight: 38)
                .padding(.horizontal, 12)
                .background(
                    Capsule().fill(
                        isOn
                            ? Theme.Editorial.onSurface.opacity(0.12)
                            : Color.clear
                    )
                )
                .overlay(
                    Capsule().stroke(
                        isOn
                            ? Theme.Editorial.onSurface
                            : Theme.Editorial.hairline,
                        lineWidth: isOn ? 1 : 0.5
                    )
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.rawValue)
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }

    private func toggle(_ option: DietaryRestriction) {
        if let index = selected.firstIndex(of: option) {
            selected.remove(at: index)
        } else {
            selected.append(option)
        }
    }
}

#Preview {
    @Previewable @State var picks: [DietaryRestriction] = [.vegetarian, .nutAllergy]
    return ZStack {
        Theme.Editorial.nightGradient.ignoresSafeArea()
        ScrollView {
            AllergyChipGrid(selected: $picks)
                .padding(28)
        }
    }
}
