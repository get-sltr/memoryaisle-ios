

import SwiftUI

enum Typography {

    // MARK: - Display (SF Pro, Medium)

    static let displayLarge = Font.system(size: 34, weight: .medium, design: .default)
    static let displayMedium = Font.system(size: 28, weight: .medium, design: .default)
    static let displaySmall = Font.system(size: 22, weight: .medium, design: .default)

    // MARK: - Body (SF Pro, Regular)

    static let bodyLarge = Font.system(size: 17, weight: .regular, design: .default)
    static let bodyMedium = Font.system(size: 15, weight: .regular, design: .default)
    static let bodySmall = Font.system(size: 13, weight: .regular, design: .default)
    static let caption = Font.system(size: 11, weight: .regular, design: .default)

    // MARK: - Monospace (SF Mono, for data/macros/numbers)

    static let monoLarge = Font.system(size: 28, weight: .regular, design: .monospaced)
    static let monoMedium = Font.system(size: 17, weight: .regular, design: .monospaced)
    static let monoSmall = Font.system(size: 13, weight: .regular, design: .monospaced)

    // MARK: - Emphasis Variants

    static let bodyLargeBold = Font.system(size: 17, weight: .semibold, design: .default)
    static let bodyMediumBold = Font.system(size: 15, weight: .semibold, design: .default)
    static let bodySmallBold = Font.system(size: 13, weight: .semibold, design: .default)
    static let monoMediumBold = Font.system(size: 17, weight: .semibold, design: .monospaced)
}
