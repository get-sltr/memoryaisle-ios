import SwiftUI

struct WorriesScreen: View {
    @Binding var selected: [Worry]
    let onContinue: () -> Void
    @State private var otherText = ""
    @State private var showOtherField = false

    var body: some View {
        VStack(spacing: 0) {
            MiraWaveform(state: .idle, size: .hero)
                .frame(height: 50)
                .padding(.top, 16)
                .padding(.bottom, 20)

            Text("What worries you\nmost right now?")
                .font(.system(size: 26, weight: .light, design: .serif))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .tracking(0.3)

            Text("Select all that apply")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.25))
                .padding(.top, 8)
                .padding(.bottom, 20)

            ScrollView(showsIndicators: false) {
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
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(isSelected ? Color.violet.opacity(0.18) : .white.opacity(0.03))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(isSelected ? Color.violet.opacity(0.4) : .clear, lineWidth: 0.5)
                                )
                                .shadow(color: isSelected ? Color.violet.opacity(0.2) : .clear, radius: 12, y: 2)
                        }
                        .buttonStyle(.plain)
                    }

                    // Other option
                    Button {
                        HapticManager.selection()
                        withAnimation(.easeOut(duration: 0.2)) {
                            showOtherField.toggle()
                        }
                    } label: {
                        Text("Something else")
                            .font(.system(size: 15, weight: showOtherField ? .medium : .regular))
                            .foregroundStyle(.white.opacity(showOtherField ? 1 : 0.6))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(showOtherField ? Color.violet.opacity(0.18) : .white.opacity(0.03))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(showOtherField ? Color.violet.opacity(0.4) : .clear, lineWidth: 0.5)
                            )
                            .shadow(color: showOtherField ? Color.violet.opacity(0.2) : .clear, radius: 12, y: 2)
                    }
                    .buttonStyle(.plain)

                    if showOtherField {
                        TextField("Tell us what's on your mind...", text: $otherText, axis: .vertical)
                            .font(.system(size: 15))
                            .foregroundStyle(.white)
                            .lineLimit(3)
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(.white.opacity(0.04))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(.white.opacity(0.08), lineWidth: 0.5)
                            )
                            .transition(.opacity.combined(with: .move(edge: .top)))
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
            .opacity(selected.isEmpty && !showOtherField ? 0.3 : 1)
            .disabled(selected.isEmpty && !showOtherField)
        }
    }
}
