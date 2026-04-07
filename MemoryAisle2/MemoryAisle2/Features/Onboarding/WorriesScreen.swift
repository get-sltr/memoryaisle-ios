import SwiftUI

struct WorriesScreen: View {
    @Binding var selected: [Worry]
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 20)

            Text("What worries you\nmost right now?")
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            Text("Select all that apply")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(.white.opacity(0.25))
                .padding(.top, 8)
                .padding(.bottom, 24)

            VStack(spacing: 6) {
                ForEach(Worry.allCases, id: \.self) { worry in
                    let isSelected = selected.contains(worry)

                    Button {
                        HapticManager.selection()
                        withAnimation(.easeOut(duration: 0.15)) {
                            if isSelected {
                                selected.removeAll { $0 == worry }
                            } else {
                                selected.append(worry)
                            }
                        }
                    } label: {
                        Text(worry.rawValue)
                            .font(.system(size: 15, weight: isSelected ? .medium : .regular))
                            .foregroundStyle(.white.opacity(isSelected ? 1 : 0.6))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 13)
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

            GlowButton("Continue") {
                onContinue()
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 56)
            .opacity(selected.isEmpty ? 0.3 : 1)
            .disabled(selected.isEmpty)
        }
    }
}
