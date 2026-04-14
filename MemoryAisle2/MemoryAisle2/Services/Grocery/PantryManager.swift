import Combine
import Foundation
import SwiftData

@MainActor
final class PantryManager: ObservableObject {
    private let modelContext: ModelContext

    @Published var items: [PantryItem] = []

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func refresh() {
        let descriptor = FetchDescriptor<PantryItem>(
            sortBy: [SortDescriptor(\.addedDate, order: .reverse)]
        )
        items = (try? modelContext.fetch(descriptor)) ?? []
    }

    func addItem(name: String, category: PantryCategory = .other) {
        let item = PantryItem(name: name, category: category, isInPantry: true)
        modelContext.insert(item)
        items.insert(item, at: 0)
    }

    func removeItem(_ item: PantryItem) {
        modelContext.delete(item)
        items.removeAll { $0.id == item.id }
    }

    func hasIngredient(_ ingredient: String) -> Bool {
        let lower = ingredient.lowercased()
        return items.contains {
            $0.name.lowercased().contains(lower)
        }
    }

    func missingIngredients(
        from ingredients: [String]
    ) -> [String] {
        ingredients.filter { !hasIngredient($0) }
    }

    func itemsByCategory() -> [PantryCategory: [PantryItem]] {
        Dictionary(grouping: items, by: \.category)
    }

    var proteinItems: [PantryItem] {
        items.filter {
            $0.category == .protein || $0.category == .dairy
        }
    }

    func suggestProteinSources() -> [String] {
        let proteinFoods = proteinItems.map(\.name)
        if proteinFoods.isEmpty {
            return [
                "Greek yogurt", "Cottage cheese",
                "Chicken breast", "Canned tuna",
                "Eggs", "Protein powder",
            ]
        }
        return proteinFoods
    }
}
