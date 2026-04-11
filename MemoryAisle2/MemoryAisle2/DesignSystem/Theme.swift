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

        // Backward-compatible (violet only) — existing call sites keep working.
        static func glass(for scheme: ColorScheme) -> Color {
            glass(section: .home, for: scheme)
        }

        static func strong(for scheme: ColorScheme) -> Color {
            strong(section: .home, for: scheme)
        }

        static func pressed(for scheme: ColorScheme) -> Color {
            pressed(section: .home, for: scheme)
        }

        // Pastel tinted glass for list rows and secondary cards.
        static func glass(section: SectionID, for scheme: ColorScheme) -> Color {
            let base = SectionPalette.primary(section, for: scheme)
            return scheme == .dark ? base.opacity(0.08) : base.opacity(0.10)
        }

        static func strong(section: SectionID, for scheme: ColorScheme) -> Color {
            let base = SectionPalette.primary(section, for: scheme)
            return scheme == .dark ? base.opacity(0.14) : base.opacity(0.18)
        }

        static func pressed(section: SectionID, for scheme: ColorScheme) -> Color {
            let base = SectionPalette.primary(section, for: scheme)
            return scheme == .dark ? base.opacity(0.22) : base.opacity(0.28)
        }

        // Bold tile glow — RadialGradient for StatTile backgrounds.
        static func tile(section: SectionID, for scheme: ColorScheme) -> RadialGradient {
            let hue = SectionPalette.primary(section, for: scheme)
            return RadialGradient(
                colors: [
                    hue.opacity(0.55),
                    hue.opacity(0.0)
                ],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 260
            )
        }
    }

    // MARK: Border

    enum Border {
        static func glass(for scheme: ColorScheme) -> Color {
            scheme == .dark
                ? Color.violet.opacity(0.10)
                : Color.lavender.opacity(0.2)
        }

        static func strong(for scheme: ColorScheme) -> Color {
            scheme == .dark
                ? Color.violet.opacity(0.14)
                : Color.lavender.opacity(0.3)
        }

        static func pressed(for scheme: ColorScheme) -> Color {
            scheme == .dark
                ? Color.violet.opacity(0.25)
                : Color.lavender.opacity(0.35)
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

        static func info(for scheme: ColorScheme) -> Color {
            scheme == .dark ? Color(hex: 0x60A5FA) : Color(hex: 0x2563EB)
        }

        static func success(for scheme: ColorScheme) -> Color {
            scheme == .dark ? Color(hex: 0x4ADE80) : Color(hex: 0x16A34A)
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
    // Brand anchor
    nonisolated static let violet = Color(hex: 0xA78BFA)
    nonisolated static let violetDeep = Color(hex: 0x7C3AED)
    nonisolated static let violetMid = Color(hex: 0x8B5CF6)
    nonisolated static let lavender = Color(hex: 0xC4B5FD)
    nonisolated static let indigoBlack = Color(hex: 0x0A0914)

    // Pantry — emerald
    nonisolated static let emerald = Color(hex: 0x10B981)
    nonisolated static let emeraldDeep = Color(hex: 0x047857)
    nonisolated static let emeraldMid = Color(hex: 0x059669)
    nonisolated static let emeraldSoft = Color(hex: 0x6EE7B7)

    // Recipes — amber
    nonisolated static let amber = Color(hex: 0xF59E0B)
    nonisolated static let amberDeep = Color(hex: 0xB45309)
    nonisolated static let amberMid = Color(hex: 0xD97706)
    nonisolated static let amberSoft = Color(hex: 0xFCD34D)

    // Scanner — cyan
    nonisolated static let cyan = Color(hex: 0x06B6D4)
    nonisolated static let cyanDeep = Color(hex: 0x0E7490)
    nonisolated static let cyanMid = Color(hex: 0x0891B2)
    nonisolated static let cyanSoft = Color(hex: 0x67E8F9)

    // Grocery — sky
    nonisolated static let sky = Color(hex: 0x0EA5E9)
    nonisolated static let skyDeep = Color(hex: 0x0369A1)
    nonisolated static let skyMid = Color(hex: 0x0284C7)
    nonisolated static let skySoft = Color(hex: 0x7DD3FC)

    // Calendar — rose
    nonisolated static let rose = Color(hex: 0xF472B6)
    nonisolated static let roseDeep = Color(hex: 0xBE185D)
    nonisolated static let roseMid = Color(hex: 0xDB2777)
    nonisolated static let roseSoft = Color(hex: 0xFBCFE8)

    // Progress — lime
    nonisolated static let lime = Color(hex: 0x84CC16)
    nonisolated static let limeDeep = Color(hex: 0x4D7C0F)
    nonisolated static let limeMid = Color(hex: 0x65A30D)
    nonisolated static let limeSoft = Color(hex: 0xBEF264)
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
