import SwiftUI

// Generic circular icon button — filter, more, search, settings, etc.
// 44×44 tap target, 40×40 visual, section-aware glass + border.
struct IconButton: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.sectionID) private var sectionID
    let systemName: String
    let accessibilityLabel: String
    let action: () -> Void

    init(
        systemName: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) {
        self.systemName = systemName
        self.accessibilityLabel = accessibilityLabel
        self.action = action
    }

    var body: some View {
        Button(action: {
            HapticManager.light()
            action()
        }) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(SectionPalette.primary(sectionID, for: scheme))
                .frame(width: 40, height: 40)
                .background(
                    Circle().fill(Theme.Section.glass(sectionID, for: scheme))
                )
                .overlay(
                    Circle().stroke(
                        Theme.Section.border(sectionID, for: scheme),
                        lineWidth: Theme.glassBorderWidth
                    )
                )
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

#Preview("IconButton — each section") {
    VStack(spacing: 12) {
        ForEach(SectionID.allCases, id: \.self) { id in
            HStack(spacing: 12) {
                IconButton(systemName: "magnifyingglass", accessibilityLabel: "Search", action: {}).section(id)
                IconButton(systemName: "line.3.horizontal.decrease", accessibilityLabel: "Filter", action: {}).section(id)
                IconButton(systemName: "ellipsis", accessibilityLabel: "More", action: {}).section(id)
                Spacer()
            }
            .padding(.horizontal)
        }
    }
    .padding(.vertical)
    .background(Color.indigoBlack)
    .preferredColorScheme(.dark)
}
