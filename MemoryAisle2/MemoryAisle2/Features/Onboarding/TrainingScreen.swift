import SwiftUI

struct TrainingScreen: View {
    @Binding var selection: TrainingLevel
    let onContinue: () -> Void

    private func iconFor(_ level: TrainingLevel) -> String {
        switch level {
        case .lifts: "dumbbell.fill"
        case .cardio: "figure.run"
        case .sometimes: "figure.walk"
        case .none: "sofa.fill"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("Do you train or\nexercise regularly?")
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.bottom, 36)

            VStack(spacing: 8) {
                ForEach(TrainingLevel.allCases, id: \.self) { level in
                    let isSelected = selection == level

                    Button {
                        HapticManager.selection()
                        withAnimation(.easeOut(duration: 0.15)) {
                            selection = level
                        }
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: iconFor(level))
                                .font(.system(size: 15))
                                .foregroundStyle(isSelected ? Color.violet : .white.opacity(0.3))
                                .frame(width: 22)

                            Text(level.rawValue)
                                .font(.system(size: 15, weight: isSelected ? .medium : .regular))
                                .foregroundStyle(.white.opacity(isSelected ? 1 : 0.6))

                            Spacer()
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(isSelected ? Color.violet.opacity(0.18) : .white.opacity(0.03))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(
                                    isSelected ? Color.violet.opacity(0.4) : .clear,
                                    lineWidth: 0.5
                                )
                        )
                        .shadow(
                            color: isSelected ? Color.violet.opacity(0.2) : .clear,
                            radius: 12,
                            y: 2
                        )
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
