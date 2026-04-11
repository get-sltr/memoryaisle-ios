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
        // Backward-compatible — existing call sites keep working (violet).
        static func glass(for scheme: ColorScheme) -> Color {
            glass(section: .home, for: scheme)
        }

        static func strong(for scheme: ColorScheme) -> Color {
            strong(section: .home, for: scheme)
        }

        static func pressed(for scheme: ColorScheme) -> Color {
            pressed(section: .home, for: scheme)
        }

        // Pastel border for content (list rows, inline cards).
        static func glass(section: SectionID, for scheme: ColorScheme) -> Color {
            let base = SectionPalette.primary(section, for: scheme)
            return scheme == .dark ? base.opacity(0.22) : base.opacity(0.28)
        }

        static func strong(section: SectionID, for scheme: ColorScheme) -> Color {
            let base = SectionPalette.primary(section, for: scheme)
            return scheme == .dark ? base.opacity(0.32) : base.opacity(0.40)
        }

        static func pressed(section: SectionID, for scheme: ColorScheme) -> Color {
            let base = SectionPalette.primary(section, for: scheme)
            return scheme == .dark ? base.opacity(0.45) : base.opacity(0.55)
        }

        // Bright tile border — higher opacity for the hero moments.
        static func glow(section: SectionID, for scheme: ColorScheme) -> Color {
            let base = SectionPalette.primary(section, for: scheme)
            return scheme == .dark ? base.opacity(0.40) : base.opacity(0.50)
        }
    }

    // MARK: Section (convenience wrappers)

    enum Section {
        static func tile(_ id: SectionID, for scheme: ColorScheme) -> RadialGradient {
            Surface.tile(section: id, for: scheme)
        }

        static func glass(_ id: SectionID, for scheme: ColorScheme) -> Color {
            Surface.glass(section: id, for: scheme)
        }

        static func border(_ id: SectionID, for scheme: ColorScheme) -> Color {
            Border.glass(section: id, for: scheme)
        }

        static func glow(_ id: SectionID, for scheme: ColorScheme) -> Color {
            Border.glow(section: id, for: scheme)
        }

        static func primary(_ id: SectionID, for scheme: ColorScheme) -> Color {
            SectionPalette.primary(id, for: scheme)
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
