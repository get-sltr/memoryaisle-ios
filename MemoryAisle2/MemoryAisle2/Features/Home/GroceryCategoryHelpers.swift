import SwiftUI

/// Functional category mapping for the grocery list. Keeps `GroceryListScreen`
/// under the 300-line cap. Hex colors are kept as-is — they're functional
/// category badges, not theme tokens, and exist to give the user a fast
/// at-a-glance read of what's in their cart.

enum GroceryCategoryHelpers {

    static func color(for category: PantryCategory) -> Color {
        switch category {
        case .protein:      Color(hex: 0xF87171)
        case .produce:      Color(hex: 0x4ADE80)
        case .dairy:        Color(hex: 0x38BDF8)
        case .grains:       Color(hex: 0xFBBF24)
        case .frozen:       Color(hex: 0x67E8F9)
        case .pantryStaple: Color(hex: 0xA78BFA)
        case .snacks:       Color(hex: 0xFB923C)
        case .beverages:    Color(hex: 0x60A5FA)
        case .condiments:   Color(hex: 0xF472B6)
        case .other:        Color(hex: 0x9CA3AF)
        }
    }

    static func categorize(_ name: String) -> PantryCategory {
        let lower = name.lowercased()

        if matches(lower, in: ["chicken", "beef", "pork", "steak", "salmon", "tuna", "shrimp", "turkey", "fish", "lamb", "bacon", "sausage", "tofu", "tempeh", "egg"]) {
            return .protein
        }
        if matches(lower, in: ["apple", "banana", "orange", "berry", "grape", "lemon", "lime", "avocado", "tomato", "onion", "garlic", "pepper", "lettuce", "spinach", "kale", "broccoli", "carrot", "celery", "cucumber", "potato", "mushroom", "corn", "mango", "pineapple", "watermelon", "strawberry", "blueberry"]) {
            return .produce
        }
        if matches(lower, in: ["milk", "cheese", "yogurt", "butter", "cream", "cottage", "mozzarella", "cheddar", "parmesan"]) {
            return .dairy
        }
        if matches(lower, in: ["bread", "rice", "pasta", "oat", "cereal", "quinoa", "tortilla", "wrap", "bagel", "noodle", "flour"]) {
            return .grains
        }
        if matches(lower, in: ["frozen", "ice cream", "popsicle", "pizza"]) { return .frozen }
        if matches(lower, in: ["water", "juice", "soda", "coffee", "tea", "kombucha", "wine", "beer"]) {
            return .beverages
        }
        if matches(lower, in: ["chips", "crackers", "nuts", "popcorn", "granola", "bar", "cookie", "chocolate"]) {
            return .snacks
        }
        if matches(lower, in: ["sauce", "ketchup", "mustard", "mayo", "dressing", "oil", "vinegar", "soy", "salt", "pepper", "spice", "seasoning", "honey", "syrup"]) {
            return .condiments
        }
        return .other
    }

    private static func matches(_ name: String, in keywords: [String]) -> Bool {
        keywords.contains { name.contains($0) }
    }
}
