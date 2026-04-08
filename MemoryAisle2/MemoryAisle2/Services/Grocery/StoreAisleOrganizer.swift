import Foundation

struct StoreAisleOrganizer {

    static let aisleOrder: [GroceryListCategory] = [
        .produce,
        .protein,
        .dairy,
        .frozen,
        .grains,
        .pantryStaples,
        .beverages,
        .snacks,
        .supplements,
    ]

    static func organize(
        _ items: [GroceryListItem]
    ) -> [(category: GroceryListCategory, items: [GroceryListItem])] {
        let grouped = Dictionary(grouping: items, by: \.category)

        return aisleOrder.compactMap { category in
            guard let categoryItems = grouped[category],
                  !categoryItems.isEmpty else {
                return nil
            }
            let sorted = categoryItems.sorted { $0.name < $1.name }
            return (category: category, items: sorted)
        }
    }

    static func prioritize(
        _ items: [GroceryListItem],
        proteinDeficit: Double
    ) -> [GroceryListItem] {
        if proteinDeficit <= 0 {
            return items
        }

        return items.sorted { a, b in
            if a.proteinContribution > 0 && b.proteinContribution == 0 {
                return true
            }
            if a.proteinContribution == 0 && b.proteinContribution > 0 {
                return false
            }
            return a.proteinContribution > b.proteinContribution
        }
    }

    static func estimatedTripTime(itemCount: Int) -> String {
        let minutes = max(10, itemCount * 2 + 5)
        if minutes < 60 {
            return "\(minutes) min"
        }
        let hours = minutes / 60
        let remaining = minutes % 60
        return "\(hours)h \(remaining)m"
    }

    static func totalEstimatedCost(
        _ items: [GroceryListItem]
    ) -> Double? {
        let priced = items.compactMap(\.estimatedPrice)
        guard !priced.isEmpty else { return nil }
        return priced.reduce(0, +)
    }
}
