import SwiftUI

struct TrainingScreen: View {
    @Environment(\.colorScheme) private var scheme
    @Binding var selection: TrainingLevel
    let onContinue: () -> Void

    private func iconFor(_ level: TrainingLevel) -> String {
        switch level {
        case .lifts:         "dumbbell.fill"
        case .cardio:        "figure.run"
        case .sometimes:     "figure.walk"
        case .none:          "sofa.fill"
        case .nutritionOnly: "leaf.fill"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            OnboardingLogo()
                .padding(.bottom, 28)

            Text("Do you train or\nexercise regularly?")
                .font(.system(size: 26, weight: .light, design: .serif))
                .foregroundStyle(Theme.Text.primary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .tracking(0.3)
                .padding(.bottom, 32)

            VStack(spacing: 8) {
                ForEach(TrainingLevel.allCases, id: \.self) { level in
                    let isSelected = selection == level

                    Button {
                        HapticManager.selection()
                        withAnimation(.easeOut(duration: 0.15)) {
                            selection = level
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: iconFor(level))
                                .font(.system(size: 14))
                                .foregroundStyle(isSelected ? Color.violet : Theme.Text.tertiary(for: scheme))
                                .frame(width: 20)

                            Text(level.rawValue)
                                .font(.system(size: 15, weight: isSelected ? .medium : .regular))
                                .foregroundStyle(isSelected ? Theme.Text.primary : Theme.Text.secondary(for: scheme))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(isSelected ? Color.violet.opacity(0.18) : Theme.Surface.glass(for: scheme))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(isSelected ? Color.violet.opacity(0.4) : .clear, lineWidth: 0.5)
                        )
                        .shadow(color: isSelected ? Color.violet.opacity(0.2) : .clear, radius: 12, y: 2)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 28)

            Spacer()
            Spacer()

            GlowButton("Continue") {
                onContinue()
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 56)
        }
    }
}
