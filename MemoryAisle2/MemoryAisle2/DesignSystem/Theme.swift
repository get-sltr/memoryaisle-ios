import SwiftUI

// MARK: - Color System

enum Theme {

    // MARK: Background

    static func background(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.indigoBlack : Color.white
    }

    // MARK: Surface (Glass)

    enum Surface {
        static let glass = Color.violet.opacity(0.04)
        static let strong = Color.violet.opacity(0.07)
        static let pressed = Color.violet.opacity(0.12)

        static func glass(for scheme: ColorScheme) -> Color {
            scheme == .dark
                ? Color.violet.opacity(0.04)
                : Color.violetDeep.opacity(0.03)
        }

        static func strong(for scheme: ColorScheme) -> Color {
            scheme == .dark
                ? Color.violet.opacity(0.07)
                : Color.violetDeep.opacity(0.05)
        }

        static func pressed(for scheme: ColorScheme) -> Color {
            scheme == .dark
                ? Color.violet.opacity(0.12)
                : Color.violetDeep.opacity(0.08)
        }
    }

    // MARK: Border

    enum Border {
        static func glass(for scheme: ColorScheme) -> Color {
            scheme == .dark
                ? Color.violet.opacity(0.10)
                : Color.violetDeep.opacity(0.07)
        }

        static func strong(for scheme: ColorScheme) -> Color {
            scheme == .dark
                ? Color.violet.opacity(0.14)
                : Color.violetDeep.opacity(0.12)
        }

        static func pressed(for scheme: ColorScheme) -> Color {
            scheme == .dark
                ? Color.violet.opacity(0.25)
                : Color.violetDeep.opacity(0.18)
        }
    }

    // MARK: Text

    enum Text {
        static let primary = Color(.label)

        static func secondary(for scheme: ColorScheme) -> Color {
            scheme == .dark
                ? Color.white.opacity(0.5)
                : Color(hex: 0x9CA3AF)
        }

        static func tertiary(for scheme: ColorScheme) -> Color {
            scheme == .dark
                ? Color.white.opacity(0.25)
                : Color(hex: 0xD1D5DB)
        }
    }

    // MARK: Accent

    enum Accent {
        static func primary(for scheme: ColorScheme) -> Color {
            scheme == .dark ? .violet : .violetDeep
        }

        static func label(for scheme: ColorScheme) -> Color {
            scheme == .dark ? Color.violet.opacity(0.5) : .violetMid
        }
    }

    // MARK: Semantic

    enum Semantic {
        static func protein(for scheme: ColorScheme) -> Color {
            scheme == .dark ? .violet : .violetDeep
        }

        static func water(for scheme: ColorScheme) -> Color {
            scheme == .dark ? Color(hex: 0x38BDF8) : Color(hex: 0x0EA5E9)
        }

        static func fiber(for scheme: ColorScheme) -> Color {
            scheme == .dark ? Color(hex: 0xFBBF24) : Color(hex: 0xD97706)
        }

        static func calories(for scheme: ColorScheme) -> Color {
            scheme == .dark ? Color.white.opacity(0.5) : Color(hex: 0x6B7280)
        }

        static func onTrack(for scheme: ColorScheme) -> Color {
            scheme == .dark ? Color(hex: 0x34D399) : Color(hex: 0x059669)
        }

        static func behind(for scheme: ColorScheme) -> Color {
            scheme == .dark ? Color(hex: 0xFBBF24) : Color(hex: 0xD97706)
        }

        static func warning(for scheme: ColorScheme) -> Color {
            scheme == .dark ? Color(hex: 0xF87171) : Color(hex: 0xDC2626)
        }
    }

    // MARK: Spacing

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    // MARK: Radius

    enum Radius {
        static let none: CGFloat = 0
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 18
        static let full: CGFloat = 9999
    }

    // MARK: Animation

    enum Motion {
        static let press = Animation.easeOut(duration: 0.12)
        static let spring = Animation.spring(response: 0.35, dampingFraction: 0.7)
        static let gentle = Animation.easeInOut(duration: 0.3)
        static let slow = Animation.easeInOut(duration: 0.6)
    }

    // MARK: Glass Border Width

    static let glassBorderWidth: CGFloat = 0.5
}

// MARK: - Named Colors

extension Color {
    static let violet = Color(hex: 0xA78BFA)
    static let violetDeep = Color(hex: 0x7C3AED)
    static let violetMid = Color(hex: 0x8B5CF6)
    static let indigoBlack = Color(hex: 0x0A0914)
}

// MARK: - Hex Initializer

extension Color {
    nonisolated init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

// MARK: - Adaptive Background

extension View {
    func themeBackground() -> some View {
        modifier(ThemeBackgroundModifier())
    }
}

private struct ThemeBackgroundModifier: ViewModifier {
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        content
            .background(scheme == .dark ? Color.indigoBlack : Color.white)
    }
}
