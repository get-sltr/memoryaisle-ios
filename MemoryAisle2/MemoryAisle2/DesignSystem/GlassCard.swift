import SwiftUI

struct GlassCard<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.sectionID) private var ambientSection
    let sectionOverride: SectionID?
    let content: () -> Content

    init(
        section: SectionID? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.sectionOverride = section
        self.content = content
    }

    private var effectiveSection: SectionID { sectionOverride ?? ambientSection }

    var body: some View {
        content()
            .background(Theme.Section.glass(effectiveSection, for: scheme))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                    .stroke(Theme.Section.border(effectiveSection, for: scheme), lineWidth: Theme.glassBorderWidth)
            )
    }
}

struct InteractiveGlassCard<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.sectionID) private var ambientSection
    @State private var isPressed = false
    let sectionOverride: SectionID?
    let action: () -> Void
    let content: () -> Content

    init(
        section: SectionID? = nil,
        action: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.sectionOverride = section
        self.action = action
        self.content = content
    }

    private var effectiveSection: SectionID { sectionOverride ?? ambientSection }

    var body: some View {
        Button(action: {
            HapticManager.light()
            action()
        }) {
            content()
                .background(
                    isPressed
                        ? Theme.Surface.pressed(section: effectiveSection, for: scheme)
                        : Theme.Section.glass(effectiveSection, for: scheme)
                )
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                        .stroke(
                            isPressed
                                ? Theme.Border.pressed(section: effectiveSection, for: scheme)
                                : Theme.Section.border(effectiveSection, for: scheme),
                            lineWidth: Theme.glassBorderWidth
                        )
                )
        }
        .buttonStyle(GlassPressStyle())
    }
}

// MARK: - Press Style

struct GlassPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(Theme.Motion.press, value: configuration.isPressed)
    }
}

// MARK: - View Modifier Variant

struct GlassCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.sectionID) private var sectionID

    func body(content: Content) -> some View {
        content
            .background(Theme.Section.glass(sectionID, for: scheme))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                    .stroke(Theme.Section.border(sectionID, for: scheme), lineWidth: Theme.glassBorderWidth)
            )
    }
}

extension View {
    func glassCard() -> some View {
        modifier(GlassCardModifier())
    }
}
