import SwiftUI

/// Horizontal scroll of filter chips for the Reflection page. Five chips:
/// All moments, Photos, Meals, Gym, Feelings. Active chip uses violet
/// accent, inactive uses glass surface. Tapping triggers a selection
/// haptic and animates the selection swap.
struct ReflectionFilterChipRow: View {
    @Binding var selected: ReflectionFilter

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(ReflectionFilter.allCases) { filter in
                    chip(for: filter)
                }
            }
            .padding(.horizontal, 28)
        }
    }

    private func chip(for filter: ReflectionFilter) -> some View {
        let isActive = filter == selected
        return Button {
            HapticManager.selection()
            withAnimation(.easeOut(duration: 0.18)) {
                selected = filter
            }
        } label: {
            Text(filter.rawValue)
                .font(.system(size: 13))
                .foregroundStyle(isActive
                    ? Color.violet
                    : Theme.Text.secondary(for: scheme))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isActive
                            ? Color.violet.opacity(0.08)
                            : Theme.Surface.glass(for: scheme))
                )
                .overlay(
                    Capsule()
                        .stroke(isActive
                            ? Color.violet.opacity(0.25)
                            : Theme.Border.glass(for: scheme),
                            lineWidth: Theme.glassBorderWidth)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(filter.rawValue)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}
