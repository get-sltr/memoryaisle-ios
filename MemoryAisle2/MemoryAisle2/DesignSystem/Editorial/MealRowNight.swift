import SwiftUI

/// Night-mode meal row. Identical content to `MealRow` (time, name, macros)
/// but laid out with a leading checkmark dot and slightly muted body — the
/// evening recap reads as "this is what we did today" rather than "here's
/// what to make."
struct MealRowNight: View {
    let time: String
    let name: String
    let proteinGrams: Int
    let calories: Int
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button {
            onTap?()
        } label: {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Theme.Editorial.onSurface)
                        .frame(width: 16, height: 16)
                    Text("✓")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(Theme.Editorial.nightTop)
                }
                .padding(.top, 5)

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
                        .opacity(0.65)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 16) {
                        MacroLabel(value: "\(proteinGrams)", unit: "g protein")
                        MacroLabel(value: "\(calories)", unit: " cal")
                    }
                    .opacity(0.85)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 14)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Theme.Editorial.hairlineSoft)
                    .frame(height: 0.5)
            }
        }
        .buttonStyle(.plain)
        .disabled(onTap == nil)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(time), \(name), \(proteinGrams) grams protein, \(calories) calories, completed")
    }
}
