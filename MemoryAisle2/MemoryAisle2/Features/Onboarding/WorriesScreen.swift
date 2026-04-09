import SwiftUI

struct WorriesScreen: View {
    @Environment(\.colorScheme) private var scheme
    @Binding var selected: [Worry]
    let onContinue: () -> Void
    @State private var otherText = ""
    @State private var showOtherField = false

    var body: some View {
        VStack(spacing: 0) {
            OnboardingLogo()
                .padding(.top, 16)
                .padding(.bottom, 20)

            Text("What worries you\nmost right now?")
                .font(.system(size: 26, weight: .light, design: .serif))
                .foregroundStyle(Theme.Text.primary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .tracking(0.3)

            Text("Select all that apply")
                .font(.system(size: 13))
                .foregroundStyle(Theme.Text.tertiary(for: scheme))
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
                                .foregroundStyle(isSelected ? Theme.Text.primary : Theme.Text.secondary(for: scheme))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
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

                    // Other option
                    Button {
                        HapticManager.selection()
                        withAnimation(.easeOut(duration: 0.2)) {
                            showOtherField.toggle()
                        }
                    } label: {
                        Text("Something else")
                            .font(.system(size: 15, weight: showOtherField ? .medium : .regular))
                            .foregroundStyle(showOtherField ? Theme.Text.primary : Theme.Text.secondary(for: scheme))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(showOtherField ? Color.violet.opacity(0.18) : Theme.Surface.glass(for: scheme))
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
                            .foregroundStyle(Theme.Text.primary)
                            .lineLimit(3)
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Theme.Surface.glass(for: scheme))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Theme.Border.glass(for: scheme), lineWidth: Theme.glassBorderWidth)
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
