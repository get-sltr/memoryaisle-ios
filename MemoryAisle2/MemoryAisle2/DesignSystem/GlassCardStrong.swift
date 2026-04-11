import SwiftUI

struct GlassCardStrong<Content: View>: View {
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
            .background(Theme.Surface.strong(section: effectiveSection, for: scheme))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                    .stroke(Theme.Border.strong(section: effectiveSection, for: scheme), lineWidth: Theme.glassBorderWidth)
            )
    }
}

struct InteractiveGlassCardStrong<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.sectionID) private var ambientSection
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
                .background(Theme.Surface.strong(section: effectiveSection, for: scheme))
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                        .stroke(Theme.Border.strong(section: effectiveSection, for: scheme), lineWidth: Theme.glassBorderWidth)
                )
        }
        .buttonStyle(GlassPressStyle())
    }
}

extension View {
    func glassCardStrong() -> some View {
        modifier(GlassCardStrongModifier())
    }
}

private struct GlassCardStrongModifier: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.sectionID) private var sectionID

    func body(content: Content) -> some View {
        content
            .background(Theme.Surface.strong(section: sectionID, for: scheme))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                    .stroke(Theme.Border.strong(section: sectionID, for: scheme), lineWidth: Theme.glassBorderWidth)
            )
    }
}
