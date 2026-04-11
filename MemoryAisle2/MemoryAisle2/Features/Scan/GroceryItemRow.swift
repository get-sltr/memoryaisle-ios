import SwiftUI

struct GroceryItemRow: View {
    @Environment(\.colorScheme) private var scheme
    let item: GroceryItem
    let categoryColor: UInt
    let onToggle: () -> Void
    let onDelete: () -> Void

    private var catColor: Color { Color(hex: categoryColor) }

    var body: some View {
        Button(action: onToggle) {
            rowContent
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("Remove", systemImage: "trash")
            }
        }
    }

    private var rowContent: some View {
        HStack(spacing: 12) {
            checkIcon
            nameLabel
            Spacer()
            if !item.isChecked { detailLabels }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(rowBackground)
        .overlay(rowBorder)
        .padding(.horizontal, 16)
    }

    private var checkIcon: some View {
        Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 18))
            .foregroundStyle(
                item.isChecked
                    ? Theme.Semantic.onTrack(for: scheme)
                    : catColor.opacity(0.55)
            )
    }

    private var nameLabel: some View {
        Text(item.name)
            .font(.system(size: 15, weight: item.isChecked ? .regular : .medium))
            .foregroundStyle(
                item.isChecked
                    ? Theme.Text.tertiary(for: scheme)
                    : Theme.Text.primary
            )
            .strikethrough(item.isChecked, color: Theme.Text.tertiary(for: scheme))
    }

    private var detailLabels: some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(item.quantity)
                .font(.system(size: 11))
                .foregroundStyle(Theme.Text.tertiary(for: scheme))
            if let protein = item.proteinPer {
                Text(protein)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(catColor.opacity(0.65))
            }
        }
    }

    @ViewBuilder
    private var rowBackground: some View {
        if item.isChecked {
            Color.clear
        } else {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [catColor.opacity(0.10), catColor.opacity(0.04)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
    }

    @ViewBuilder
    private var rowBorder: some View {
        if !item.isChecked {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(catColor.opacity(0.18), lineWidth: 0.5)
        }
    }
}
