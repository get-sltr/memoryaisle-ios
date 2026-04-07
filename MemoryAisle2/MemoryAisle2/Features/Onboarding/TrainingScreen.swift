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

            VStack(spacing: 10) {
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
                                .font(.system(size: 16))
                                .foregroundStyle(isSelected ? Color.violet : .white.opacity(0.35))
                                .frame(width: 24)

                            Text(level.rawValue)
                                .font(.system(size: 15, weight: .regular))
                                .foregroundStyle(.white)

                            Spacer()

                            Circle()
                                .strokeBorder(
                                    isSelected ? Color.violet : .white.opacity(0.15),
                                    lineWidth: isSelected ? 0 : 1.5
                                )
                                .background(Circle().fill(isSelected ? Color.violet : .clear))
                                .overlay(
                                    isSelected
                                        ? Image(systemName: "checkmark")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(.white)
                                        : nil
                                )
                                .frame(width: 22, height: 22)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .background(.ultraThinMaterial.opacity(0.4))
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(isSelected ? Color.violet.opacity(0.08) : .white.opacity(0.02))
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(
                                    isSelected ? Color.violet.opacity(0.25) : .white.opacity(0.06),
                                    lineWidth: 0.5
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)

            Spacer()
            Spacer()

            VioletButton("Continue") {
                onContinue()
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 56)
        }
    }
}
