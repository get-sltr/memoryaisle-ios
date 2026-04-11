import SwiftUI

// MARK: - Section Identity

enum SectionID: String, CaseIterable, Sendable {
    case home
    case pantry
    case recipes
    case scanner
    case grocery
    case calendar
    case progress
    case mira
}

// MARK: - Section Style Lookups

enum SectionPalette {

    // Primary hue for the section. Used for tile glows, chip fills, accent rings.
    static func primary(_ id: SectionID, for scheme: ColorScheme) -> Color {
        switch id {
        case .home, .mira: return scheme == .dark ? .violet : .violetDeep
        case .pantry:      return scheme == .dark ? .emerald : .emeraldDeep
        case .recipes:     return scheme == .dark ? .amber : .amberDeep
        case .scanner:     return scheme == .dark ? .cyan : .cyanDeep
        case .grocery:     return scheme == .dark ? .sky : .skyDeep
        case .calendar:    return scheme == .dark ? .rose : .roseDeep
        case .progress:    return scheme == .dark ? .lime : .limeDeep
        }
    }

    // Mid tone used for gradient stops.
    static func mid(_ id: SectionID, for scheme: ColorScheme) -> Color {
        switch id {
        case .home, .mira: return .violetMid
        case .pantry:      return .emeraldMid
        case .recipes:     return .amberMid
        case .scanner:     return .cyanMid
        case .grocery:     return .skyMid
        case .calendar:    return .roseMid
        case .progress:    return .limeMid
        }
    }

    // Soft tone used for readable labels on dark surfaces and for chips.
    static func soft(_ id: SectionID) -> Color {
        switch id {
        case .home, .mira: return .lavender
        case .pantry:      return .emeraldSoft
        case .recipes:     return .amberSoft
        case .scanner:     return .cyanSoft
        case .grocery:     return .skySoft
        case .calendar:    return .roseSoft
        case .progress:    return .limeSoft
        }
    }

    // Hero mesh: returns the 3 tones used by MeshGradientView.
    // For Mira, returns the Aurora trio (violet + cyan + rose).
    static func meshTones(_ id: SectionID, for scheme: ColorScheme) -> (Color, Color, Color) {
        switch id {
        case .mira:
            return (
                scheme == .dark ? .violet : .violetDeep,
                scheme == .dark ? .cyan : .cyanMid,
                scheme == .dark ? .rose : .roseMid
            )
        case .home:
            return (.violet, .violetMid, .lavender)
        case .pantry:
            return (.emerald, .cyan, .emeraldSoft)
        case .recipes:
            return (.amber, .rose, .amberSoft)
        case .scanner:
            return (.cyan, .violet, .cyanSoft)
        case .grocery:
            return (.sky, .violet, .skySoft)
        case .calendar:
            return (.rose, .violet, .roseSoft)
        case .progress:
            return (.lime, .violet, .limeSoft)
        }
    }
}

// MARK: - Environment Key

private struct SectionIDKey: EnvironmentKey {
    static let defaultValue: SectionID = .home
}

extension EnvironmentValues {
    var sectionID: SectionID {
        get { self[SectionIDKey.self] }
        set { self[SectionIDKey.self] = newValue }
    }
}

extension View {
    // Sets the section identity for all descendant views.
    func section(_ id: SectionID) -> some View {
        environment(\.sectionID, id)
    }
}
