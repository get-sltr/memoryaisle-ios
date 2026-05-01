import SwiftData
import SwiftUI

struct PantryView: View {
    var mode: MAMode = .auto
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<PantryItem> { $0.isInPantry == true },
        sort: \PantryItem.addedDate,
        order: .reverse
    ) private var items: [PantryItem]
    @State private var showAddItem = false
    @State private var newItemName = ""
    @State private var newItemCategory: PantryCategory = .other

    private var grouped: [(PantryCategory, [PantryItem])] {
        let dict = Dictionary(grouping: items) { $0.category }
        return PantryCategory.allCases.compactMap { cat in
            guard let items = dict[cat], !items.isEmpty else { return nil }
            return (cat, items)
        }
    }

    private var heroTrailing: String {
        let count = items.count
        if count == 0 { return "EMPTY" }
        return "\(count) \(count == 1 ? "ITEM" : "ITEMS")"
    }

    var body: some View {
        ZStack {
            EditorialBackground(mode: mode)

            VStack(alignment: .leading, spacing: 0) {
                topBar
                Masthead(wordmark: "PANTRY", trailing: heroTrailing)
                    .padding(.bottom, 22)

                if items.isEmpty {
                    emptyState
                } else {
                    listScroll
                }
            }
            .padding(.horizontal, Theme.Editorial.Spacing.pad)
            .padding(.top, 12)
        }
        .preferredColorScheme(.light)
        .alert("Add Item", isPresented: $showAddItem) {
            TextField("Item name", text: $newItemName)
            Button("Add") {
                guard !newItemName.isEmpty else { return }
                let item = PantryItem(
                    name: newItemName,
                    category: newItemCategory,
                    isInPantry: true
                )
                modelContext.insert(item)
                newItemName = ""
                HapticManager.success()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 8) {
            Spacer()
            Button { showAddItem = true } label: {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.Editorial.onSurface)
                    .frame(width: 32, height: 32)
                    .overlay(Circle().stroke(Theme.Editorial.hairline, lineWidth: 0.5))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add pantry item")

            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.Editorial.onSurface)
                    .frame(width: 32, height: 32)
                    .overlay(Circle().stroke(Theme.Editorial.hairline, lineWidth: 0.5))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
        .padding(.bottom, 14)
    }

    // MARK: - List

    private var listScroll: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 26) {
                ForEach(grouped, id: \.0) { category, categoryItems in
                    categorySection(category, items: categoryItems)
                }
                Spacer(minLength: 80)
            }
        }
    }

    private func categorySection(_ category: PantryCategory, items: [PantryItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.Editorial.onSurface)
                Text(category.rawValue.uppercased())
                    .font(Theme.Editorial.Typography.capsBold(10))
                    .tracking(3)
                    .foregroundStyle(Theme.Editorial.onSurface)
            }
            HairlineDivider().opacity(0.5)
            VStack(spacing: 0) {
                ForEach(items) { item in
                    itemRow(item)
                    HairlineDivider().opacity(0.3)
                }
            }
        }
    }

    private func itemRow(_ item: PantryItem) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(Theme.Editorial.Typography.body())
                    .foregroundStyle(Theme.Editorial.onSurface)
                if !item.brand.isEmpty {
                    Text(item.brand.uppercased())
                        .font(Theme.Editorial.Typography.caps(9, weight: .semibold))
                        .tracking(1.4)
                        .foregroundStyle(Theme.Editorial.onSurfaceFaint)
                }
            }

            Spacer()

            if item.proteinPer100g > 0 {
                Text("\(Int(item.proteinPer100g))G")
                    .font(Theme.Editorial.Typography.dataValue())
                    .tracking(1.2)
                    .foregroundStyle(Theme.Editorial.onSurfaceMuted)
            }

            Button {
                modelContext.delete(item)
                HapticManager.light()
            } label: {
                Image(systemName: "minus.circle")
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.Editorial.onSurfaceFaint)
            }
            .accessibilityLabel("Remove \(item.name)")
        }
        .padding(.vertical, 12)
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "refrigerator.fill")
                .font(.system(size: 44))
                .foregroundStyle(Theme.Editorial.onSurfaceFaint)
            Text("YOUR PANTRY IS EMPTY")
                .font(Theme.Editorial.Typography.capsBold(11))
                .tracking(3)
                .foregroundStyle(Theme.Editorial.onSurface)
            Text("Scan barcodes or add items manually.\nMira uses your pantry to suggest meals.")
                .font(Theme.Editorial.Typography.body())
                .foregroundStyle(Theme.Editorial.onSurfaceMuted)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
            Button { showAddItem = true } label: {
                Text("ADD FIRST ITEM")
                    .font(Theme.Editorial.Typography.capsBold(11))
                    .tracking(3)
                    .foregroundStyle(Theme.Editorial.onSurface)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .overlay(Capsule().stroke(Theme.Editorial.onSurface, lineWidth: 0.5))
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
