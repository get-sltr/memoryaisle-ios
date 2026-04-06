import SwiftUI

struct GhostButton: View {
    @Environment(\.colorScheme) private var scheme

    let title: String
    let icon: String?
    let action: () -> Void

    init(_ title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    var body: some View {
        Button(action: {
            HapticManager.light()
            action()
        }) {
            HStack(spacing: Theme.Spacing.sm) {
                if let icon {
                    Image(systemName: icon)
                        .font(Typography.bodyMedium)
                }
                Text(title)
                    .font(Typography.bodyLargeBold)
            }
            .foregroundStyle(Theme.Accent.primary(for: scheme))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Theme.Surface.glass(for: scheme))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .stroke(Theme.Border.glass(for: scheme), lineWidth: Theme.glassBorderWidth)
            )
        }
        .buttonStyle(GhostPressStyle())
    }
}

struct GhostButtonCompact: View {
    @Environment(\.colorScheme) private var scheme

    let title: String
    let icon: String?
    let action: () -> Void

    init(_ title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    var body: some View {
        Button(action: {
            HapticManager.light()
            action()
        }) {
            HStack(spacing: Theme.Spacing.xs) {
                if let icon {
                    Image(systemName: icon)
                        .font(Typography.bodySmall)
                }
                Text(title)
                    .font(Typography.bodyMediumBold)
            }
            .foregroundStyle(Theme.Accent.primary(for: scheme))
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .background(Theme.Surface.glass(for: scheme))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                    .stroke(Theme.Border.glass(for: scheme), lineWidth: Theme.glassBorderWidth)
            )
        }
        .buttonStyle(GhostPressStyle())
    }
}

private struct GhostPressStyle: ButtonStyle {
    @Environment(\.colorScheme) private var scheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .background(
                configuration.isPressed
                    ? Theme.Surface.pressed(for: scheme)
                    : Color.clear
            )
            .animation(Theme.Motion.press, value: configuration.isPressed)
    }
}
