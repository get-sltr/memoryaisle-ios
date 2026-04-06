import SwiftUI

struct GlassCardStrong<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        content()
            .background(Theme.Surface.strong(for: scheme))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                    .stroke(Theme.Border.strong(for: scheme), lineWidth: Theme.glassBorderWidth)
            )
    }
}

struct InteractiveGlassCardStrong<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    let action: () -> Void
    let content: () -> Content

    init(action: @escaping () -> Void, @ViewBuilder content: @escaping () -> Content) {
        self.action = action
        self.content = content
    }

    var body: some View {
        Button(action: {
            HapticManager.light()
            action()
        }) {
            content()
                .background(Theme.Surface.strong(for: scheme))
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                        .stroke(Theme.Border.strong(for: scheme), lineWidth: Theme.glassBorderWidth)
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

    func body(content: Content) -> some View {
        content
            .background(Theme.Surface.strong(for: scheme))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                    .stroke(Theme.Border.strong(for: scheme), lineWidth: Theme.glassBorderWidth)
            )
    }
}
