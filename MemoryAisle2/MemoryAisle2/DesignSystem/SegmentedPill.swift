import SwiftUI

// Animated segmented control with a matched-geometry selection indicator
// that slides between options. Section-aware.
struct SegmentedPill<Value: Hashable>: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.sectionID) private var sectionID
    @Namespace private var selectionNS

    let options: [(value: Value, label: String)]
    @Binding var selection: Value

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.value) { option in
                Button(action: {
                    guard option.value != selection else { return }
                    HapticManager.light()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        selection = option.value
                    }
                }) {
                    Text(option.label)
                        .font(Typography.bodyMediumBold)
                        .foregroundStyle(
                            option.value == selection
                                ? Color.white
                                : SectionPalette.primary(sectionID, for: scheme)
                        )
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background {
                            if option.value == selection {
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                SectionPalette.primary(sectionID, for: scheme),
                                                SectionPalette.mid(sectionID, for: scheme)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .matchedGeometryEffect(id: "pill", in: selectionNS)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(option.label)
                .accessibilityAddTraits(option.value == selection ? [.isSelected] : [])
            }
        }
        .padding(4)
        .background(
            Capsule().fill(Theme.Section.glass(sectionID, for: scheme))
        )
        .overlay(
            Capsule().stroke(
                Theme.Section.border(sectionID, for: scheme),
                lineWidth: Theme.glassBorderWidth
            )
        )
    }
}

#Preview("SegmentedPill — each section") {
    struct Host: View {
        @State var selection = "day"
        var body: some View {
            VStack(spacing: 16) {
                ForEach(SectionID.allCases, id: \.self) { id in
                    SegmentedPill(
                        options: [("day", "Day"), ("week", "Week"), ("month", "Month")],
                        selection: $selection
                    )
                    .section(id)
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }
    return Host()
        .background(Color.indigoBlack)
        .preferredColorScheme(.dark)
}
