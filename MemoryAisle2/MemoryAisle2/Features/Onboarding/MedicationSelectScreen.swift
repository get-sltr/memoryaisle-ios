import SwiftUI

struct MedicationSelectScreen: View {
    @Binding var selection: Medication?
    let onContinue: () -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 0) {
            Text("Which medication\nare you on?")
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.top, 40)
                .padding(.bottom, 28)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 8) {
                    ForEach(Medication.allCases, id: \.self) { med in
                        medOption(med)
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
            .opacity(selection != nil ? 1 : 0.3)
            .disabled(selection == nil)
        }
    }

    private func medOption(_ med: Medication) -> some View {
        let isSelected = selection == med

        return Button {
            HapticManager.selection()
            withAnimation(.easeOut(duration: 0.15)) {
                selection = med
            }
        } label: {
            HStack {
                Text(med.rawValue)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(.white)

                Spacer()

                Circle()
                    .strokeBorder(
                        isSelected ? Color.violet : .white.opacity(0.15),
                        lineWidth: isSelected ? 0 : 1.5
                    )
                    .background(
                        Circle()
                            .fill(isSelected ? Color.violet : .clear)
                    )
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
}
