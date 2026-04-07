import SwiftUI

struct MedicationSelectScreen: View {
    @Binding var selection: Medication?
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            MiraWaveform(state: .idle, size: .hero)
                .frame(height: 50)
                .padding(.top, 16)
                .padding(.bottom, 20)

            Text("Which medication\nare you on?")
                .font(.system(size: 26, weight: .light, design: .serif))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .tracking(0.3)
                .padding(.bottom, 20)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 6) {
                    ForEach(Medication.allCases, id: \.self) { med in
                        let isSelected = selection == med

                        Button {
                            HapticManager.selection()
                            withAnimation(.easeOut(duration: 0.15)) {
                                selection = med
                            }
                        } label: {
                            Text(med.rawValue)
                                .font(.system(size: 15, weight: isSelected ? .medium : .regular))
                                .foregroundStyle(.white.opacity(isSelected ? 1 : 0.6))
                                .frame(maxWidth: .infinity)
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
                                    radius: 12, y: 2
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 28)
            }

            GlowButton("Continue") {
                onContinue()
            }
            .padding(.horizontal, 32)
            .padding(.top, 12)
            .padding(.bottom, 56)
            .opacity(selection != nil ? 1 : 0.3)
            .disabled(selection == nil)
        }
    }
}
