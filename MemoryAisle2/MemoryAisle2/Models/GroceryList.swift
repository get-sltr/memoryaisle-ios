import Foundation
import SwiftData

@Model
final class GroceryList {
    var id: String
    var createdAt: Date
    var isCompleted: Bool
    var items: [GroceryListItem]

    init(items: [GroceryListItem] = []) {
        self.id = UUID().uuidString
        self.createdAt = Date()
        self.isCompleted = false
        self.items = items
    }

    var pendingItems: [GroceryListItem] {
        items.filter { !$0.isPurchased }
    }

    var purchasedItems: [GroceryListItem] {
        items.filter { $0.isPurchased }
    }

    var completionPercent: Double {
        guard !items.isEmpty else { return 0 }
        return Double(purchasedItems.count) / Double(items.count)
    }
}

struct GroceryListItem: Codable, Identifiable {
    var id: String
    var name: String
    var category: GroceryListCategory
    var quantity: String
    var isPurchased: Bool
    var proteinContribution: Double
    var estimatedPrice: Double?

    init(
        name: String,
        category: GroceryListCategory,
        quantity: String = "1",
        proteinContribution: Double = 0,
        estimatedPrice: Double? = nil
    ) {
        self.id = UUID().uuidString
        self.name = name
        self.category = category
        self.quantity = quantity
        self.isPurchased = false
        self.proteinContribution = proteinContribution
        self.estimatedPrice = estimatedPrice
    }
}

enum GroceryListCategory: String, Codable, CaseIterable {
    case protein = "Protein"
    case dairy = "Dairy"
    case produce = "Produce"
    case grains = "Grains"
    case frozen = "Frozen"
    case pantryStaples = "Pantry"
    case beverages = "Beverages"
    case snacks = "Snacks"
    case supplements = "Supplements"
}
