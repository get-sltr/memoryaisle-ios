import SwiftUI

struct TrainingScreen: View {
    @Binding var selection: TrainingLevel
    let onContinue: () -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("Do you train or\nexercise regularly?")
                .font(Typography.displaySmall)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.bottom, Theme.Spacing.xl)

            VStack(spacing: Theme.Spacing.sm) {
                ForEach(TrainingLevel.allCases, id: \.self) { level in
                    trainingOption(level)
                }
            }
            .padding(.horizontal, Theme.Spacing.md)

            Spacer()

            VioletButton("Continue") {
                onContinue()
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.lg)
        }
    }

    private func trainingOption(_ level: TrainingLevel) -> some View {
        let isSelected = selection == level

        return Button {
            HapticManager.selection()
            withAnimation(Theme.Motion.press) {
                selection = level
            }
        } label: {
            HStack {
                Image(systemName: iconFor(level))
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? Color.violet : .white.opacity(0.4))
                    .frame(width: 28)

                Text(level.rawValue)
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
                        isSelected ? Color.violet.opacity(0.3) : Theme.Border.glass(for: scheme),
                        lineWidth: isSelected ? 1 : Theme.glassBorderWidth
                    )
            )
        }
        .buttonStyle(GlassPressStyle())
    }

    private func iconFor(_ level: TrainingLevel) -> String {
        switch level {
        case .lifts: "dumbbell.fill"
        case .cardio: "figure.run"
        case .sometimes: "figure.walk"
        case .none: "sofa.fill"
        }
    }
}
