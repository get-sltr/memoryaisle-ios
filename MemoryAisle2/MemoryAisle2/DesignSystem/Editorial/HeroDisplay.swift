import SwiftUI

/// Three-line italic hero block — first and third lines regular,
/// middle line italic, all serif at displayHero size.
struct HeroDisplay: View {
    let lineOne: String
    let lineTwoItalic: String
    let lineThree: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(lineOne)
                .font(Theme.Editorial.Typography.displayHero())
            Text(lineTwoItalic)
                .font(Theme.Editorial.Typography.displayHeroItalic())
                .italic()
            Text(lineThree)
                .font(Theme.Editorial.Typography.displayHero())
        }
        .kerning(-1.0)
        .lineSpacing(-6)
        .foregroundStyle(Theme.Editorial.onSurface)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(lineOne) \(lineTwoItalic) \(lineThree)")
    }
}
