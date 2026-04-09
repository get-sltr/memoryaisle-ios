import SwiftData
import SwiftUI

struct PantryView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PantryItem.addedDate, order: .reverse) private var items: [PantryItem]
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

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.violet.opacity(0.6))
                }

                Spacer()

                Text("My Pantry")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Theme.Text.primary)

                Spacer()

                Button {
                    showAddItem = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.violet)
                        
                        .background(Circle().fill(Color.violet.opacity(0.1)))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            if items.isEmpty {
                emptyState
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        ForEach(grouped, id: \.0) { category, categoryItems in
                            categorySection(category, items: categoryItems)
                        }
                        Spacer(minLength: 40)
                    }
                    .padding(.top, 16)
                }
            }
        }
        .themeBackground()
        .alert("Add Item", isPresented: $showAddItem) {
            TextField("Item name", text: $newItemName)
            Button("Add") {
                guard !newItemName.isEmpty else { return }
                let item = PantryItem(name: newItemName, category: newItemCategory)
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
                .font(.system(size: 36))
                .foregroundStyle(Theme.Text.tertiary(for: scheme))

            Text("Your pantry is empty")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.Text.secondary(for: scheme))

            Text("Scan barcodes or add items manually.\nMira uses your pantry to suggest meals.")
                .font(.system(size: 13))
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
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.violet.opacity(0.6))
                Text(category.rawValue.uppercased())
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Theme.Text.tertiary(for: scheme))
                    .tracking(1.2)
            }
            .padding(.horizontal, 20)

            ForEach(items) { item in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name)
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.Text.primary)
                        if !item.brand.isEmpty {
                            Text(item.brand)
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.Text.tertiary(for: scheme))
                        }
                    }

                    Spacer()

                    if item.proteinPer100g > 0 {
                        Text("\(Int(item.proteinPer100g))g")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(Color.violet.opacity(0.6))
                    }

                    Button {
                        modelContext.delete(item)
                        HapticManager.light()
                    } label: {
                        Image(systemName: "minus.circle")
                            .font(.system(size: 16))
                            .foregroundStyle(Theme.Text.tertiary(for: scheme))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Theme.Surface.glass(for: scheme))
                )
                .padding(.horizontal, 16)
            }
        }
    }
}
