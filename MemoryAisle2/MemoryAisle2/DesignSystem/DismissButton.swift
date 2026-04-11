import SwiftUI

// Universal back/dismiss affordance. Chevron-left inside a glass pill.
// 44pt tap target height, haptic light on tap, section-aware.
struct DismissButton: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.sectionID) private var sectionID
    let label: String?
    let action: () -> Void

    init(label: String? = nil, action: @escaping () -> Void) {
        self.label = label
        self.action = action
    }

    var body: some View {
        Button(action: {
            HapticManager.light()
            action()
        }) {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .bold))
                if let label {
                    Text(label)
                        .font(Typography.bodyMediumBold)
                }
            }
            .foregroundStyle(Color(.label))
            .padding(.horizontal, label == nil ? 0 : 12)
            .frame(minWidth: 32, minHeight: 32)
            .background(
                Capsule().fill(Theme.Section.glass(sectionID, for: scheme))
            )
            .overlay(
                Capsule().stroke(
                    Theme.Section.border(sectionID, for: scheme),
                    lineWidth: Theme.glassBorderWidth
                )
            )
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label ?? "Back")
    }
}

#Preview("DismissButton — icon only + labeled") {
    VStack(spacing: 16) {
        ForEach(SectionID.allCases, id: \.self) { id in
            HStack(spacing: 12) {
                DismissButton(action: {}).section(id)
                DismissButton(label: "Back", action: {}).section(id)
                Spacer()
            }
            .padding(.horizontal)
        }
    }
    .padding(.vertical)
    .background(Color.indigoBlack)
    .preferredColorScheme(.dark)
}
