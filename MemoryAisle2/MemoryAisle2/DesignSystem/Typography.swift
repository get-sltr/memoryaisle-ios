

import SwiftUI

enum Typography {

    // MARK: - Display (SF Pro, Medium)

    static let displayLarge = Font.system(size: 34, weight: .medium, design: .default)
    static let displayMedium = Font.system(size: 28, weight: .medium, design: .default)
    static let displaySmall = Font.system(size: 22, weight: .medium, design: .default)

    // MARK: - Title (SF Pro, for headings/section headers)

    static let titleLarge = Font.system(size: 24, weight: .light, design: .default)
    static let titleMedium = Font.system(size: 20, weight: .light, design: .default)
    static let titleSmall = Font.system(size: 18, weight: .semibold, design: .default)

    // MARK: - Serif (SF Pro Serif, for branded headings)

    static let serifLarge = Font.system(size: 28, weight: .light, design: .serif)
    static let serifMedium = Font.system(size: 24, weight: .light, design: .serif)
    static let serifSmall = Font.system(size: 20, weight: .light, design: .serif)

    // MARK: - Body (SF Pro, Regular)

    static let bodyLarge = Font.system(size: 17, weight: .regular, design: .default)
    static let bodyMedium = Font.system(size: 15, weight: .regular, design: .default)
    static let bodySmall = Font.system(size: 13, weight: .regular, design: .default)
    static let caption = Font.system(size: 11, weight: .regular, design: .default)
    static let label = Font.system(size: 10, weight: .regular, design: .default)

    // MARK: - Monospace (SF Mono, for data/macros/numbers)

    static let monoLarge = Font.system(size: 28, weight: .regular, design: .monospaced)
    static let monoMedium = Font.system(size: 17, weight: .regular, design: .monospaced)
    static let monoSmall = Font.system(size: 13, weight: .regular, design: .monospaced)

    // MARK: - Emphasis Variants

    static let bodyLargeBold = Font.system(size: 17, weight: .semibold, design: .default)
    static let bodyMediumBold = Font.system(size: 15, weight: .semibold, design: .default)
    static let bodySmallBold = Font.system(size: 13, weight: .semibold, design: .default)
    static let monoMediumBold = Font.system(size: 17, weight: .semibold, design: .monospaced)
    static let displaySmallMono = Font.system(size: 22, weight: .light, design: .monospaced)

    // MARK: - Ported from Flair pass (used by dashboard components)

    static let micro = Font.system(size: 10, weight: .medium, design: .default)
    static let data = Font.system(size: 22, weight: .medium, design: .monospaced)
    static let dataSmall = Font.system(size: 15, weight: .medium, design: .monospaced)
}

// MARK: - Typography View Modifiers (ported from Flair pass)

extension View {
    func letterSpaced(_ spacing: CGFloat = 1.0) -> some View {
        self.tracking(spacing)
    }

    func tabularFigures() -> some View {
        self.monospacedDigit()
    }
}
