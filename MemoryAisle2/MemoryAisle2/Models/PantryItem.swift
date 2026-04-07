import Foundation
import SwiftData

@Model
final class PantryItem {
    var name: String
    var brand: String
    var barcode: String?
    var proteinPer100g: Double
    var caloriesPer100g: Int
    var addedDate: Date
    var expiryDate: Date?
    var category: PantryCategory
    var isStaple: Bool

    init(
        name: String,
        brand: String = "",
        barcode: String? = nil,
        proteinPer100g: Double = 0,
        caloriesPer100g: Int = 0,
        expiryDate: Date? = nil,
        category: PantryCategory = .other,
        isStaple: Bool = false
    ) {
        self.name = name
        self.brand = brand
        self.barcode = barcode
        self.proteinPer100g = proteinPer100g
        self.caloriesPer100g = caloriesPer100g
        self.addedDate = .now
        self.expiryDate = expiryDate
        self.category = category
        self.isStaple = isStaple
    }
}

enum PantryCategory: String, Codable, CaseIterable {
    case protein = "Protein"
    case dairy = "Dairy"
    case grains = "Grains"
    case produce = "Produce"
    case frozen = "Frozen"
    case pantryStaple = "Pantry"
    case snacks = "Snacks"
    case beverages = "Beverages"
    case condiments = "Condiments"
    case other = "Other"

    var icon: String {
        switch self {
        case .protein: "flame.fill"
        case .dairy: "cup.and.saucer.fill"
        case .grains: "leaf.fill"
        case .produce: "carrot.fill"
        case .frozen: "snowflake"
        case .pantryStaple: "bag.fill"
        case .snacks: "popcorn.fill"
        case .beverages: "drop.fill"
        case .condiments: "flask.fill"
        case .other: "square.grid.2x2.fill"
        }
    }
}
