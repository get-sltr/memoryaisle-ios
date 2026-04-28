import SwiftUI

struct MealRow: View {
    let time: String
    let name: String
    let proteinGrams: Int
    let calories: Int
    let prepMinutes: Int
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button {
            onTap?()
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(time)
                    .font(Theme.Editorial.Typography.capsBold(9))
                    .tracking(2.2)
                    .foregroundStyle(Theme.Editorial.onSurface)
                    .opacity(0.85)

                Text(name)
                    .font(Theme.Editorial.Typography.mealName())
                    .kerning(-0.3)
                    .foregroundStyle(Theme.Editorial.onSurface)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 16) {
                    MacroLabel(value: "\(proteinGrams)", unit: "g protein")
                    MacroLabel(value: "\(calories)", unit: " cal")
                    MacroLabel(value: "\(prepMinutes)", unit: " min")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 16)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Theme.Editorial.hairlineSoft)
                    .frame(height: 0.5)
            }
        }
        .buttonStyle(.plain)
        .disabled(onTap == nil)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(time), \(name), \(proteinGrams) grams protein, \(calories) calories, \(prepMinutes) minutes")
    }
}
