import SwiftUI

struct WorriesScreen: View {
    @Binding var selected: [Worry]
    let onContinue: () -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 0) {
            Text("What worries you\nmost right now?")
                .font(Typography.displaySmall)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.top, Theme.Spacing.xl)

            Text("Select all that apply")
                .font(Typography.bodySmall)
                .foregroundStyle(.white.opacity(0.4))
                .padding(.top, Theme.Spacing.sm)
                .padding(.bottom, Theme.Spacing.lg)

            ScrollView {
                VStack(spacing: Theme.Spacing.sm) {
                    ForEach(Worry.allCases, id: \.self) { worry in
                        worryOption(worry)
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
            }

            VioletButton("Continue") {
                onContinue()
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.lg)
            .opacity(selected.isEmpty ? 0.4 : 1)
            .disabled(selected.isEmpty)
        }
    }

    private func worryOption(_ worry: Worry) -> some View {
        let isSelected = selected.contains(worry)

        return Button {
            HapticManager.selection()
            withAnimation(Theme.Motion.press) {
                if isSelected {
                    selected.removeAll { $0 == worry }
                } else {
                    selected.append(worry)
                }
            }
        } label: {
            HStack {
                Text(worry.rawValue)
                    .font(Typography.bodyMedium)
                    .foregroundStyle(.white)

                Spacer()

                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundStyle(isSelected ? Color.violet : .white.opacity(0.3))
                    .font(.system(size: 20))
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm + 2)
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
