import SwiftUI

enum Typography {

    // MARK: - Display (SF Pro Display, Medium)

    static let displayLarge = Font.system(size: 34, weight: .medium, design: .default)
    static let displayMedium = Font.system(size: 28, weight: .medium, design: .default)
    static let displaySmall = Font.system(size: 22, weight: .medium, design: .default)

    // MARK: - Body (SF Pro Text, Regular)

    static let bodyLarge = Font.system(size: 17, weight: .regular, design: .default)
    static let bodyMedium = Font.system(size: 15, weight: .regular, design: .default)
    static let bodySmall = Font.system(size: 13, weight: .regular, design: .default)

    // MARK: - Labels

    static let label = Font.system(size: 11, weight: .medium, design: .default)
    static let caption = Font.system(size: 11, weight: .regular, design: .default)
    static let micro = Font.system(size: 10, weight: .medium, design: .default)

    // MARK: - Monospace (SF Mono, for data displays)

    static let monoLarge = Font.system(size: 28, weight: .regular, design: .monospaced)
    static let data = Font.system(size: 22, weight: .medium, design: .monospaced)
    static let dataSmall = Font.system(size: 15, weight: .medium, design: .monospaced)
    static let monoMedium = Font.system(size: 17, weight: .regular, design: .monospaced)
    static let monoSmall = Font.system(size: 13, weight: .regular, design: .monospaced)

    // MARK: - Emphasis Variants

    static let bodyLargeBold = Font.system(size: 17, weight: .semibold, design: .default)
    static let bodyMediumBold = Font.system(size: 15, weight: .medium, design: .default)
    static let bodySmallBold = Font.system(size: 13, weight: .semibold, design: .default)
    static let monoMediumBold = Font.system(size: 17, weight: .semibold, design: .monospaced)
}

// MARK: - Typography Modifiers

extension View {
    func letterSpaced(_ spacing: CGFloat = 1.0) -> some View {
        modifier(LetterSpacingModifier(spacing: spacing))
    }

    func tabularFigures() -> some View {
        modifier(TabularFiguresModifier())
    }

    func microLabel() -> some View {
        font(Typography.micro)
            .letterSpaced(0.8)
            .textCase(.uppercase)
    }
}

private struct LetterSpacingModifier: ViewModifier {
    let spacing: CGFloat

    func body(content: Content) -> some View {
        content.tracking(spacing)
    }
}

private struct TabularFiguresModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.monospacedDigit()
    }
}
