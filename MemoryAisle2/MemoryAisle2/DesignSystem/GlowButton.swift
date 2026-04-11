import SwiftUI

// Hero CTA button — reserved for "moments" (finish onboarding, scan success,
// recipe save). Outer halo glow in the section hue + one-shot pulse on appear.
struct GlowButton: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.sectionID) private var ambientSection
    @State private var appeared = false

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
            HapticManager.medium()
            action()
        }) {
            HStack(spacing: Theme.Spacing.sm) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
        }
        .buttonStyle(GlowPressStyle(section: effectiveSection, scheme: scheme, appeared: appeared))
        .accessibilityLabel(title)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                appeared = true
            }
        }
    }
}

private struct GlowPressStyle: ButtonStyle {
    let section: SectionID
    let scheme: ColorScheme
    let appeared: Bool

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let hue = SectionPalette.primary(section, for: scheme)

        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.ultraThinMaterial.opacity(pressed ? 0.9 : 0.6))
            )
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(hue.opacity(pressed ? 0.35 : 0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        hue.opacity(pressed ? 0.7 : 0.4),
                        lineWidth: pressed ? 1 : 0.5
                    )
            )
            .shadow(
                color: hue.opacity(pressed ? 0.6 : (appeared ? 0.35 : 0.0)),
                radius: pressed ? 34 : 24,
                y: 4
            )
            .shadow(
                color: hue.opacity(appeared ? 0.15 : 0.0),
                radius: 48,
                y: 10
            )
            .scaleEffect(pressed ? 0.98 : 1.0)
            .brightness(pressed ? 0.05 : 0)
            .animation(.easeOut(duration: 0.12), value: pressed)
    }
}

#Preview("GlowButton — hero per section") {
    ScrollView {
        VStack(spacing: 28) {
            ForEach(SectionID.allCases, id: \.self) { id in
                GlowButton("Continue", icon: "arrow.right") {}
                    .section(id)
                    .padding(.horizontal)
            }
        }
        .padding(.vertical, 40)
    }
    .background(Color.indigoBlack)
    .preferredColorScheme(.dark)
}
