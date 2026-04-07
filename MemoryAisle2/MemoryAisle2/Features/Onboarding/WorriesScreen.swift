import SwiftUI

struct WorriesScreen: View {
    @Binding var selected: [Worry]
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Text("What worries you\nmost right now?")
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.top, 40)

            Text("Select all that apply")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(.white.opacity(0.3))
                .padding(.top, 8)
                .padding(.bottom, 28)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 8) {
                    ForEach(Worry.allCases, id: \.self) { worry in
                        checkOption(worry.rawValue, isSelected: selected.contains(worry)) {
                            HapticManager.selection()
                            withAnimation(.easeOut(duration: 0.15)) {
                                if selected.contains(worry) {
                                    selected.removeAll { $0 == worry }
                                } else {
                                    selected.append(worry)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
            }

            VioletButton("Continue") {
                onContinue()
            }
            .padding(.horizontal, 32)
            .padding(.top, 16)
            .padding(.bottom, 56)
            .opacity(selected.isEmpty ? 0.3 : 1)
            .disabled(selected.isEmpty)
        }
    }
}

// MARK: - Shared Check Option

func checkOption(_ text: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        HStack {
            Text(text)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(.white)

            Spacer()

            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .strokeBorder(
                    isSelected ? Color.violet : .white.opacity(0.15),
                    lineWidth: isSelected ? 0 : 1.5
                )
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(isSelected ? Color.violet : .clear)
                )
                .overlay(
                    isSelected
                        ? Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                        : nil
                )
                .frame(width: 20, height: 20)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isSelected ? Color.violet.opacity(0.08) : .white.opacity(0.03))
        )
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
