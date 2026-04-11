import SwiftUI

// Universal close affordance. Use anywhere a sheet/cover/detail needs a dismiss X.
// 44×44 tap target, 22×22 visual, glass circle background, haptic light on tap.
struct CloseButton: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.sectionID) private var sectionID
    let action: () -> Void

    init(action: @escaping () -> Void) {
        self.action = action
    }

    var body: some View {
        Button(action: {
            HapticManager.light()
            action()
        }) {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color(.label))
                .frame(width: 32, height: 32)
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
        .accessibilityLabel("Close")
    }
}

#Preview("CloseButton — each section, dark") {
    ScrollView {
        VStack(spacing: 12) {
            ForEach(SectionID.allCases, id: \.self) { id in
                HStack {
                    Text(id.rawValue.capitalized)
                        .foregroundStyle(.white)
                    Spacer()
                    CloseButton(action: {}).section(id)
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }
    .background(Color.indigoBlack)
    .preferredColorScheme(.dark)
}

#Preview("CloseButton — light") {
    VStack {
        CloseButton(action: {}).section(.pantry)
        CloseButton(action: {}).section(.recipes)
    }
    .padding()
    .background(Color.white)
    .preferredColorScheme(.light)
}
