import SwiftData
import SwiftUI

struct PantryView: View {
    @Environment(\.colorScheme) private var scheme
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

    private var heroSubtitle: String {
        let count = items.count
        let cats = grouped.count
        if count == 0 { return "Empty. Let's stock it up" }
        let itemWord = count == 1 ? "item" : "items"
        let catWord = cats == 1 ? "category" : "categories"
        return "\(count) \(itemWord) · \(cats) \(catWord)"
    }

    var body: some View {
        VStack(spacing: 0) {
            HeroHeader(title: "Pantry", subtitle: heroSubtitle) {
                HStack(spacing: 8) {
                    IconButton(
                        systemName: "plus",
                        accessibilityLabel: "Add pantry item"
                    ) {
                        showAddItem = true
                    }
                    CloseButton(action: { dismiss() })
                }
            }

            if items.isEmpty {
                emptyState
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 20) {
                        ForEach(grouped, id: \.0) { category, categoryItems in
                            categorySection(category, items: categoryItems)
                        }
                        Spacer(minLength: 40)
                    }
                    .padding(.top, 20)
                }
            }
        }
        .section(.pantry)
        .themeBackground()
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

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "refrigerator.fill")
                .font(Typography.displayLarge)
                .foregroundStyle(SectionPalette.primary(.pantry, for: scheme).opacity(0.35))

            Text("Your pantry is empty")
                .font(Typography.bodyLargeBold)
                .foregroundStyle(Theme.Text.secondary(for: scheme))

            Text("Scan barcodes or add items manually.\nMira uses your pantry to suggest meals.")
                .font(Typography.bodySmall)
                .foregroundStyle(Theme.Text.tertiary(for: scheme))
                .multilineTextAlignment(.center)

            GlowButton("Add first item") {
                showAddItem = true
            }
            .padding(.horizontal, 60)

            Spacer()
            Spacer()
        }
    }

    private func categorySection(_ category: PantryCategory, items: [PantryItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(SectionPalette.primary(.pantry, for: scheme))
                    .frame(width: 2, height: 14)
                Image(systemName: category.icon)
                    .font(Typography.caption)
                    .foregroundStyle(SectionPalette.primary(.pantry, for: scheme))
                Text(category.rawValue.uppercased())
                    .font(Typography.label)
                    .foregroundStyle(SectionPalette.soft(.pantry))
                    .tracking(1.2)
            }
            .padding(.horizontal, 20)

            VStack(spacing: 8) {
                ForEach(items) { item in
                    SectionCard {
                        itemRow(item)
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    private func itemRow(_ item: PantryItem) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(Typography.bodyMedium)
                    .foregroundStyle(Theme.Text.primary)
                if !item.brand.isEmpty {
                    Text(item.brand)
                        .font(Typography.caption)
                        .foregroundStyle(Theme.Text.tertiary(for: scheme))
                }
            }

            Spacer()

            if item.proteinPer100g > 0 {
                Text("\(Int(item.proteinPer100g))g")
                    .font(Typography.monoSmall)
                    .foregroundStyle(SectionPalette.primary(.pantry, for: scheme))
            }

            Button {
                modelContext.delete(item)
                HapticManager.light()
            } label: {
                Image(systemName: "minus.circle")
                    .font(Typography.bodyLarge)
                    .foregroundStyle(Theme.Text.tertiary(for: scheme))
            }
            .accessibilityLabel("Remove \(item.name)")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}
