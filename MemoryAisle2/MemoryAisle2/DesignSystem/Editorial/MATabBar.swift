import SwiftUI

struct MATabBar: View {
    @Binding var selection: MATab
    var onSelect: ((MATab) -> Void)? = nil

    var body: some View {
        VStack(spacing: 14) {
            HairlineDivider()
            HStack {
                ForEach(MATab.allCases) { tab in
                    Spacer()
                    tabButton(tab)
                    Spacer()
                }
            }
        }
        .padding(.horizontal, Theme.Editorial.Spacing.tabInset)
    }

    @ViewBuilder
    private func tabButton(_ tab: MATab) -> some View {
        Button {
            HapticManager.selection()
            onSelect?(tab)
            selection = tab
        } label: {
            VStack(spacing: 6) {
                if selection == tab {
                    Circle()
                        .fill(Theme.Editorial.onSurface)
                        .frame(width: 4, height: 4)
                        .offset(y: -10)
                } else {
                    Color.clear
                        .frame(width: 4, height: 4)
                        .offset(y: -10)
                }
                Text(tab.label)
                    .font(Theme.Editorial.Typography.capsBold(11))
                    .tracking(2)
                    .foregroundStyle(Theme.Editorial.onSurface)
                    .opacity(selection == tab ? 1.0 : 0.6)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.label.lowercased())
        .accessibilityAddTraits(selection == tab ? [.isSelected, .isButton] : .isButton)
    }
}
