import SwiftUI

// Pastel list-row container — the default wrapper for any list row
// or inline card on a feature page. Reads section from environment.
struct SectionCard<Content: View>: View {
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

// Interactive variant — tap to perform an action.
struct InteractiveSectionCard<Content: View>: View {
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
        .buttonStyle(SectionCardPressStyle(isPressed: $isPressed))
    }
}

private struct SectionCardPressStyle: ButtonStyle {
    @Binding var isPressed: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(Theme.Motion.press, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, new in
                isPressed = new
            }
    }
}

#Preview("SectionCard — rows per section") {
    ScrollView {
        VStack(spacing: 10) {
            ForEach(SectionID.allCases, id: \.self) { id in
                SectionCard {
                    HStack {
                        Text(id.rawValue.capitalized)
                            .foregroundStyle(Color(.label))
                            .font(Typography.bodyLargeBold)
                            .padding(16)
                        Spacer()
                    }
                }
                .section(id)
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }
    .background(Color.indigoBlack)
    .preferredColorScheme(.dark)
}
