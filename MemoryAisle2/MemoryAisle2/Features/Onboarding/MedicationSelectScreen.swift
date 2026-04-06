import SwiftUI

struct MedicationSelectScreen: View {
    @Binding var selection: Medication?
    let onContinue: () -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 0) {
            Text("Which medication\nare you on?")
                .font(Typography.displaySmall)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.top, Theme.Spacing.xl)
                .padding(.bottom, Theme.Spacing.lg)

            ScrollView {
                VStack(spacing: Theme.Spacing.sm) {
                    ForEach(Medication.allCases, id: \.self) { med in
                        medOption(med)
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
            }

            VioletButton("Continue") {
                onContinue()
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.lg)
            .opacity(selection != nil ? 1 : 0.4)
            .disabled(selection == nil)
        }
    }

    private func medOption(_ med: Medication) -> some View {
        let isSelected = selection == med

        return Button {
            HapticManager.selection()
            withAnimation(Theme.Motion.press) {
                selection = med
            }
        } label: {
            HStack {
                Text(med.rawValue)
                    .font(Typography.bodyLarge)
                    .foregroundStyle(.white)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.violet)
                        .font(.system(size: 22))
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
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
                        isSelected
                            ? Color.violet.opacity(0.3)
                            : Theme.Border.glass(for: scheme),
                        lineWidth: isSelected ? 1 : Theme.glassBorderWidth
                    )
            )
        }
        .buttonStyle(GlassPressStyle())
    }
}
