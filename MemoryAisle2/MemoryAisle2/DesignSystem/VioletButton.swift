import SwiftUI

struct VioletButton: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.sectionID) private var ambientSection

    let title: String
    let icon: String?
    let isLoading: Bool
    let sectionOverride: SectionID?
    let action: () -> Void

    init(
        _ title: String,
        icon: String? = nil,
        isLoading: Bool = false,
        section: SectionID? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isLoading = isLoading
        self.sectionOverride = section
        self.action = action
    }

    private var effectiveSection: SectionID { sectionOverride ?? ambientSection }

    var body: some View {
        Button(action: {
            guard !isLoading else { return }
            HapticManager.medium()
            action()
        }) {
            HStack(spacing: Theme.Spacing.sm) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.85)
                } else if let icon {
                    Image(systemName: icon)
                        .font(Typography.bodyMediumBold)
                }

                Text(title)
                    .font(Typography.bodyLargeBold)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [
                        SectionPalette.primary(effectiveSection, for: scheme),
                        SectionPalette.mid(effectiveSection, for: scheme)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
        }
        .buttonStyle(VioletPressStyle(section: effectiveSection, scheme: scheme))
        .opacity(isLoading ? 0.8 : 1.0)
        .accessibilityLabel(title)
    }
}

// MARK: - Compact Variant

struct VioletButtonCompact: View {
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
            .foregroundStyle(.white)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .background(SectionPalette.primary(effectiveSection, for: scheme))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
        }
        .buttonStyle(VioletPressStyle(section: effectiveSection, scheme: scheme))
        .accessibilityLabel(title)
    }
}

// MARK: - Press Style

private struct VioletPressStyle: ButtonStyle {
    let section: SectionID
    let scheme: ColorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .brightness(configuration.isPressed ? -0.05 : 0)
            .shadow(
                color: SectionPalette.primary(section, for: scheme)
                    .opacity(configuration.isPressed ? 0.55 : 0.0),
                radius: configuration.isPressed ? 20 : 0,
                y: 0
            )
            .animation(Theme.Motion.press, value: configuration.isPressed)
    }
}

#Preview("VioletButton — each section") {
    ScrollView {
        VStack(spacing: 12) {
            ForEach(SectionID.allCases, id: \.self) { id in
                VioletButton("Continue", icon: "arrow.right") {}
                    .section(id)
                    .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }
    .background(Color.indigoBlack)
    .preferredColorScheme(.dark)
}
