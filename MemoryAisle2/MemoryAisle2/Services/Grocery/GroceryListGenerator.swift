import Foundation
import SwiftData

struct GroceryListGenerator {

    static func generate(
        from mealPlan: MealPlan,
        pantryItems: [PantryItem],
        context: ModelContext
    ) -> GroceryList {
        let allIngredients = mealPlan.meals.flatMap(\.ingredients)
        let pantryNames = Set(
            pantryItems.map { $0.name.lowercased() }
        )

        let needed = allIngredients.filter { ingredient in
            !pantryNames.contains { pantryName in
                ingredient.lowercased().contains(pantryName)
                    || pantryName.contains(ingredient.lowercased())
            }
        }

        let deduplicated = Array(Set(needed)).sorted()

        let items = deduplicated.map { ingredient in
            GroceryListItem(
                name: ingredient,
                category: categorize(ingredient),
                proteinContribution: estimateProtein(ingredient)
            )
        }

        let list = GroceryList(items: items)
        context.insert(list)
        return list
    }

    static func generateFromDeficit(
        proteinDeficitGrams: Double,
        dietaryRestrictions: [DietaryRestriction]
    ) -> [GroceryListItem] {
        var suggestions: [GroceryListItem] = []

        let proteinSources = filteredProteinSources(
            restrictions: dietaryRestrictions
        )

        var remainingProtein = proteinDeficitGrams
        for source in proteinSources {
            guard remainingProtein > 0 else { break }
            suggestions.append(source)
            remainingProtein -= source.proteinContribution
        }

        return suggestions
    }

    private static func categorize(_ ingredient: String) -> GroceryListCategory {
        let lower = ingredient.lowercased()

        let proteinKeywords = [
            "chicken", "beef", "pork", "fish", "salmon",
            "tuna", "shrimp", "turkey", "tofu", "tempeh",
            "egg", "protein",
        ]
        if proteinKeywords.contains(where: { lower.contains($0) }) {
            return .protein
        }

        let dairyKeywords = [
            "yogurt", "cheese", "milk", "cottage", "cream",
        ]
        if dairyKeywords.contains(where: { lower.contains($0) }) {
            return .dairy
        }

        let produceKeywords = [
            "apple", "banana", "berry", "spinach", "kale",
            "broccoli", "avocado", "tomato", "onion",
            "pepper", "lettuce", "carrot", "celery",
        ]
        if produceKeywords.contains(where: { lower.contains($0) }) {
            return .produce
        }

        let grainKeywords = [
            "rice", "bread", "oat", "quinoa", "pasta",
            "tortilla", "wrap",
        ]
        if grainKeywords.contains(where: { lower.contains($0) }) {
            return .grains
        }

        return .pantryStaples
    }

    private static func estimateProtein(_ name: String) -> Double {
        let lower = name.lowercased()

        let highProtein = [
            "chicken": 31.0, "turkey": 29.0, "salmon": 25.0,
            "tuna": 26.0, "beef": 26.0, "shrimp": 24.0,
            "tofu": 17.0, "tempeh": 20.0,
        ]

        for (key, value) in highProtein {
            if lower.contains(key) { return value }
        }

        let medProtein = [
            "egg": 6.0, "yogurt": 15.0, "cottage": 14.0,
            "cheese": 7.0, "milk": 8.0, "protein": 25.0,
        ]

        for (key, value) in medProtein {
            if lower.contains(key) { return value }
        }

        return 0
    }

    private static func filteredProteinSources(
        restrictions: [DietaryRestriction]
    ) -> [GroceryListItem] {
        var sources = [
            GroceryListItem(
                name: "Greek yogurt (plain, 2%)",
                category: .dairy,
                quantity: "32 oz",
                proteinContribution: 60
            ),
            GroceryListItem(
                name: "Chicken breast",
                category: .protein,
                quantity: "2 lbs",
                proteinContribution: 124
            ),
            GroceryListItem(
                name: "Eggs (dozen)",
                category: .protein,
                quantity: "1 dozen",
                proteinContribution: 72
            ),
            GroceryListItem(
                name: "Cottage cheese (low-fat)",
                category: .dairy,
                quantity: "16 oz",
                proteinContribution: 56
            ),
            GroceryListItem(
                name: "Canned tuna (in water)",
                category: .protein,
                quantity: "4 cans",
                proteinContribution: 80
            ),
        ]

        let isVegan = restrictions.contains(.vegan)
        let isVegetarian = restrictions.contains(.vegetarian)
        let isDairyFree = restrictions.contains(.dairyFree)

        if isVegan || isVegetarian {
            sources.removeAll {
                $0.category == .protein
                    && !$0.name.lowercased().contains("tofu")
            }
            sources.append(GroceryListItem(
                name: "Extra-firm tofu",
                category: .protein,
                quantity: "2 blocks",
                proteinContribution: 40
            ))
            sources.append(GroceryListItem(
                name: "Edamame (frozen, shelled)",
                category: .frozen,
                quantity: "16 oz",
                proteinContribution: 34
            ))
        }

        if isVegan || isDairyFree {
            sources.removeAll { $0.category == .dairy }
        }

        return sources
    }
}
