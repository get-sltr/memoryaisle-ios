import SwiftUI

struct DietaryScreen: View {
    @Binding var selected: [DietaryRestriction]
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Text("Any dietary\nrestrictions?")
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.top, 40)
                .padding(.bottom, 32)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 8) {
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
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(.ultraThinMaterial.opacity(0.5))
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(isSelected ? Color.violet.opacity(0.15) : Color.violet.opacity(0.04))
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(
                                            isSelected ? Color.violet.opacity(0.3) : .white.opacity(0.06),
                                            lineWidth: 0.5
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
            }

            VioletButton(selected.isEmpty ? "None, continue" : "Continue") {
                onContinue()
            }
            .padding(.horizontal, 32)
            .padding(.top, 16)
            .padding(.bottom, 56)
        }
    }
}
