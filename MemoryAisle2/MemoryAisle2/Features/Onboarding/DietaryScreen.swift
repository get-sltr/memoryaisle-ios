import SwiftUI

struct DietaryScreen: View {
    @Binding var selected: [DietaryRestriction]
    let onContinue: () -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 0) {
            Text("Any dietary\nrestrictions?")
                .font(Typography.displaySmall)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.top, Theme.Spacing.xl)
                .padding(.bottom, Theme.Spacing.lg)

            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: Theme.Spacing.sm),
                    GridItem(.flexible(), spacing: Theme.Spacing.sm)
                ], spacing: Theme.Spacing.sm) {
                    ForEach(DietaryRestriction.allCases, id: \.self) { restriction in
                        dietaryChip(restriction)
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
            }

            VioletButton(selected.isEmpty ? "None, continue" : "Continue") {
                onContinue()
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.lg)
        }
    }

    private func dietaryChip(_ restriction: DietaryRestriction) -> some View {
        let isSelected = selected.contains(restriction)

        return Button {
            HapticManager.selection()
            withAnimation(Theme.Motion.press) {
                if isSelected {
                    selected.removeAll { $0 == restriction }
                } else {
                    selected.append(restriction)
                }
            }
        } label: {
            Text(restriction.rawValue)
                .font(Typography.bodyMedium)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.sm + 4)
                .background(
                    isSelected
                        ? Theme.Surface.strong(for: scheme)
                        : Theme.Surface.glass(for: scheme)
                )
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                        .stroke(
                            isSelected ? Color.violet.opacity(0.3) : Theme.Border.glass(for: scheme),
                            lineWidth: isSelected ? 1 : Theme.glassBorderWidth
                        )
                )
        }
        .buttonStyle(GlassPressStyle())
    }
}
