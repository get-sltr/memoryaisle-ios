import SwiftUI

struct GhostButton: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.sectionID) private var ambientSection

    let title: String
    let icon: String?
    let sectionOverride: SectionID?
    let action: () -> Void

    init(
        _ title: String,
        icon: String? = nil,
        section: SectionID? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.sectionOverride = section
        self.action = action
    }

    private var effectiveSection: SectionID { sectionOverride ?? ambientSection }

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
            .foregroundStyle(SectionPalette.primary(effectiveSection, for: scheme))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Theme.Section.glass(effectiveSection, for: scheme))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .stroke(Theme.Section.border(effectiveSection, for: scheme), lineWidth: Theme.glassBorderWidth)
            )
        }
        .buttonStyle(GhostPressStyle(section: effectiveSection, scheme: scheme))
        .accessibilityLabel(title)
    }
}

struct GhostButtonCompact: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.sectionID) private var ambientSection

    let title: String
    let icon: String?
    let sectionOverride: SectionID?
    let action: () -> Void

    init(
        _ title: String,
        icon: String? = nil,
        section: SectionID? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.sectionOverride = section
        self.action = action
    }

    private var effectiveSection: SectionID { sectionOverride ?? ambientSection }

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
            .foregroundStyle(SectionPalette.primary(effectiveSection, for: scheme))
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .background(Theme.Section.glass(effectiveSection, for: scheme))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                    .stroke(Theme.Section.border(effectiveSection, for: scheme), lineWidth: Theme.glassBorderWidth)
            )
        }
        .buttonStyle(GhostPressStyle(section: effectiveSection, scheme: scheme))
        .accessibilityLabel(title)
    }
}

private struct GhostPressStyle: ButtonStyle {
    let section: SectionID
    let scheme: ColorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .background(
                configuration.isPressed
                    ? Theme.Surface.pressed(section: section, for: scheme)
                    : Color.clear
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .stroke(
                        SectionPalette.primary(section, for: scheme)
                            .opacity(configuration.isPressed ? 0.25 : 0),
                        lineWidth: 2
                    )
                    .blur(radius: 4)
                    .allowsHitTesting(false)
            )
            .animation(Theme.Motion.press, value: configuration.isPressed)
    }
}

#Preview("GhostButton — each section") {
    ScrollView {
        VStack(spacing: 12) {
            ForEach(SectionID.allCases, id: \.self) { id in
                GhostButton("Learn more", icon: "info.circle") {}
                    .section(id)
                    .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }
    .background(Color.indigoBlack)
    .preferredColorScheme(.dark)
}
