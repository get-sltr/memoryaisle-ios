import Foundation
import SwiftData

/// Shared utility for inserting raw ingredient names into the user's grocery
/// list as `PantryItem` rows (items with `isInPantry == false` show on the
/// grocery list; `true` show in the pantry).
///
/// Call sites:
///   - Mira's `addToGroceryList` chat tool (MiraToolExecutor)
///   - "Add ingredients to grocery list" on a favorited Mira suggestion's
///     detail screen (SavedRecipeDetailView)
///   - "ADD INGREDIENTS TO GROCERY" on a meal-plan row's expansion in
///     MealsView (Task 3)
///   - "PLAN WEEK'S GROCERIES" cross-week aggregation in MealsView
///
/// Dedup is done on a normalized key — lowercased, trimmed, leading
/// quantity tokens stripped — so a meal-plan ingredient like
/// "1 cup baby spinach" doesn't insert a second row when the user
/// already has "spinach" on the list. The full original string with
/// quantity is still what gets stored, so the user sees usable shopping
/// text. Quantity-aware merging (consolidating "1 cup" + "1/2 cup")
/// is intentionally out of scope — accept some noise for now.
///
/// Caller is responsible for `context.save()` so each path can handle
/// save errors how it wants.
@MainActor
enum GroceryAdder {
    struct Result {
        let added: [String]
        let skipped: [String]
    }

    static func add(_ names: [String], in context: ModelContext) -> Result {
        let descriptor = FetchDescriptor<PantryItem>()
        let existing = (try? context.fetch(descriptor)) ?? []
        let existingKeys = Set(existing.map { dedupeKey(for: $0.name) })

        var added: [String] = []
        var skipped: [String] = []
        var seenInBatch: Set<String> = []

        for raw in names {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            let key = dedupeKey(for: trimmed)
            guard !key.isEmpty else { continue }

            if existingKeys.contains(key) || seenInBatch.contains(key) {
                skipped.append(trimmed)
                continue
            }

            seenInBatch.insert(key)

            let item = PantryItem(
                name: trimmed,
                category: PantryCategorizer.categorize(trimmed)
            )
            context.insert(item)
            added.append(trimmed)
        }

        return Result(added: added, skipped: skipped)
    }

    /// Normalized key for deduplication. Strips leading quantity tokens,
    /// common units, trailing punctuation, and lowercases. v1 heuristic;
    /// quantity-aware consolidation ("1 cup" + "½ cup" → "1.5 cups") is
    /// out of scope for this pass.
    static func dedupeKey(for raw: String) -> String {
        var s = raw.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Strip trailing punctuation.
        while let last = s.last, ".,;:!?".contains(last) {
            s.removeLast()
            s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Strip a leading quantity + optional unit. Handles plain numbers,
        // fractions ("1/2", "½"), decimals, and ranges ("2-3"). The unit
        // list is the common cooking measures; anything not on the list
        // stays as-is, which is fine for matching purposes since the same
        // unit will show up identically in both keys.
        let units = [
            "cup", "cups", "tbsp", "tablespoon", "tablespoons",
            "tsp", "teaspoon", "teaspoons",
            "oz", "ounce", "ounces",
            "lb", "lbs", "pound", "pounds",
            "g", "gram", "grams", "kg",
            "ml", "l", "liter", "liters", "litre", "litres",
            "slice", "slices", "clove", "cloves",
            "can", "cans", "package", "packages", "pkg",
            "bunch", "bunches", "head", "heads"
        ]

        let tokens = s.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        guard !tokens.isEmpty else { return s }

        var i = 0

        if i < tokens.count, isQuantityToken(tokens[i]) {
            i += 1
            // Optional second quantity token after a hyphen-less range
            // (e.g., "2 to 3 cups").
            if i < tokens.count, tokens[i] == "to", i + 1 < tokens.count,
               isQuantityToken(tokens[i + 1]) {
                i += 2
            }
            if i < tokens.count, units.contains(tokens[i]) {
                i += 1
            }
        }

        return tokens.dropFirst(i).joined(separator: " ")
    }

    private static func isQuantityToken(_ token: String) -> Bool {
        // Numeric, fraction, decimal, range, or unicode fraction glyph.
        let digits = "0123456789"
        if token.first.map({ digits.contains($0) }) == true { return true }
        let unicodeFractions: Set<Character> = ["½", "¼", "¾", "⅓", "⅔", "⅛", "⅜", "⅝", "⅞"]
        if let first = token.first, unicodeFractions.contains(first) { return true }
        return false
    }

    /// Renders the user's current grocery list as a plain-text plan
    /// grouped by category, ready to share, copy, or paste into Reminders.
    /// Empty list returns an empty string so callers can no-op cleanly.
    static func sharePlainText(items: [PantryItem]) -> String {
        guard !items.isEmpty else { return "" }
        let order: [PantryCategory] = [
            .protein, .produce, .dairy, .grains, .frozen,
            .pantryStaple, .snacks, .beverages, .condiments, .other
        ]
        let grouped = Dictionary(grouping: items, by: \.category)

        var lines: [String] = ["Grocery list"]
        for category in order {
            guard let group = grouped[category], !group.isEmpty else { continue }
            lines.append("")
            lines.append(category.rawValue.uppercased())
            for item in group {
                lines.append("- \(item.name)")
            }
        }
        return lines.joined(separator: "\n")
    }
}
