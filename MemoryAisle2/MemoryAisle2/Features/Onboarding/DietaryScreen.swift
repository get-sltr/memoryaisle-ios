import SwiftUI

struct DietaryScreen: View {
    @Environment(\.colorScheme) private var scheme
    @Binding var selected: [DietaryRestriction]
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            OnboardingLogo()
                .padding(.top, 16)
                .padding(.bottom, 20)

            Text("Any dietary\nrestrictions?")
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
                    ForEach(DietaryRestriction.allCases, id: \.self) { restriction in
                        let isSelected = selected.contains(restriction)

                        Button {
                            HapticManager.selection()
                            withAnimation(.easeOut(duration: 0.15)) {
                                if isSelected {
                                    selected.removeAll { $0 == restriction }
                                } else {
                                    selected.append(restriction)
                                }
                            }
                        } label: {
                            Text(restriction.rawValue)
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
                }
                .padding(.horizontal, 28)
            }

            GlowButton(selected.isEmpty ? "None, continue" : "Continue") {
                onContinue()
            }
            .padding(.horizontal, 32)
            .padding(.top, 12)
            .padding(.bottom, 56)
        }
    }
}
