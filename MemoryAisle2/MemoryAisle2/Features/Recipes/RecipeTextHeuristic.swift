import Foundation

/// Lightweight text heuristics for deciding whether a Mira reply looks like
/// a recipe and for extracting a sensible default title when the user goes
/// to save it. Lives outside `MiraChatView` so it stays unit-testable and
/// the chat view doesn't grow further.
extension String {
    /// Conservative check: requires both an ingredients section and an
    /// instructions/steps/directions section. This keeps the "Save to
    /// Recipes" button from showing up under every Mira reply — it only
    /// appears when she actually returned something recipe-shaped.
    var looksLikeRecipe: Bool {
        let lower = self.lowercased()
        let hasIngredients = lower.contains("ingredient")
        let hasInstructions = lower.contains("instruction")
            || lower.contains("steps")
            || lower.contains("step 1")
            || lower.contains("directions")
            || lower.contains("method:")
        return hasIngredients && hasInstructions
    }

    /// Best-effort recipe title from the first non-empty line. Strips
    /// markdown headers, common conversational prefixes ("Here's a recipe
    /// for…"), and trailing punctuation. Falls back to "Untitled recipe"
    /// when nothing usable is found.
    var extractedRecipeTitle: String {
        let lines = self.split(separator: "\n", omittingEmptySubsequences: true)
        guard let first = lines.first else { return "Untitled recipe" }
        var title = String(first).trimmingCharacters(in: .whitespaces)
        title = title.trimmingCharacters(in: CharacterSet(charactersIn: "#*_ "))

        let prefixes = [
            "here's a recipe for ",
            "here is a recipe for ",
            "let me share a recipe for ",
            "let's make ",
            "try this ",
            "how about ",
            "recipe: "
        ]
        let lower = title.lowercased()
        for prefix in prefixes where lower.hasPrefix(prefix) {
            title = String(title.dropFirst(prefix.count))
            break
        }

        title = title.trimmingCharacters(in: CharacterSet(charactersIn: ":.!? "))

        if title.count > 60 {
            title = String(title.prefix(60)).trimmingCharacters(in: .whitespaces)
        }
        return title.isEmpty ? "Untitled recipe" : title
    }
}
