import Foundation
import SwiftData

/// Shared utility for inserting raw ingredient names into the user's grocery
/// list as `PantryItem` rows (items with `isInPantry == false` show on the
/// grocery list; `true` show in the pantry).
///
/// Two call sites today:
///   - Mira's `addToGroceryList` chat tool (MiraToolExecutor)
///   - "Add ingredients to grocery list" button on a favorited Mira
///     suggestion's detail screen (SavedRecipeDetailView)
///
/// Both must dedupe + categorize identically; that's why the logic lives
/// here instead of inside the tool executor. Caller is responsible for
/// `context.save()` so each path can handle save errors how it wants.
@MainActor
enum GroceryAdder {
    struct Result {
        let added: [String]
        let skipped: [String]
    }

    static func add(_ names: [String], in context: ModelContext) -> Result {
        let descriptor = FetchDescriptor<PantryItem>()
        let existing = (try? context.fetch(descriptor)) ?? []
        let existingNames = Set(existing.map { $0.name.lowercased() })

        var added: [String] = []
        var skipped: [String] = []

        for raw in names {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            if existingNames.contains(trimmed.lowercased()) {
                skipped.append(trimmed)
                continue
            }

            let item = PantryItem(
                name: trimmed,
                category: PantryCategorizer.categorize(trimmed)
            )
            context.insert(item)
            added.append(trimmed)
        }

        return Result(added: added, skipped: skipped)
    }
}
