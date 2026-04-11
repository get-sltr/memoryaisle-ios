import SwiftUI

struct MealPlanGeneratorView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @Binding var planDays: Int

    let onGenerate: (Int) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                CloseButton(action: { dismiss() })
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            Spacer()

            MiraWaveform(state: .speaking, size: .hero)
                .frame(height: 60)
                .padding(.bottom, 28)

            Text("Generate meal plan")
                .font(Typography.serifMedium)
                .foregroundStyle(Theme.Text.primary)
                .tracking(0.3)

            Text("Mira will create a personalized plan\nbased on your profile and goals.")
                .font(Typography.bodySmall)
                .foregroundStyle(Theme.Text.tertiary(for: scheme))
                .multilineTextAlignment(.center)
                .padding(.top, 8)
                .padding(.bottom, 32)

            VStack(spacing: 10) {
                Text("HOW MANY DAYS")
                    .font(Typography.label)
                    .fontWeight(.medium)
                    .foregroundStyle(SectionPalette.soft(.calendar))
                    .tracking(1.2)

                HStack(spacing: 6) {
                    ForEach([1, 3, 5, 7, 14], id: \.self) { days in
                        dayButton(days)
                    }
                }
                .padding(.horizontal, 28)
            }

            Spacer()

            GlowButton("Generate \(planDays)-day plan", icon: "sparkles") {
                onGenerate(planDays)
                dismiss()
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 56)
        }
        .section(.calendar)
        .themeBackground()
    }

    private func dayButton(_ days: Int) -> some View {
        let isSelected = planDays == days

        return Button {
            HapticManager.selection()
            planDays = days
        } label: {
            Text("\(days)")
                .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(
                    isSelected
                        ? Color.white
                        : SectionPalette.primary(.calendar, for: scheme)
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            isSelected
                                ? SectionPalette.primary(.calendar, for: scheme)
                                : Theme.Section.glass(.calendar, for: scheme)
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(
                            Theme.Section.border(.calendar, for: scheme),
                            lineWidth: Theme.glassBorderWidth
                        )
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(days) day plan")
    }
}
