import Foundation
import SwiftData

/// A recipe the user saved from a Mira conversation in the recipe browser.
/// Stored separately from the seed recipes (`RecipesSeed.all`) so it can be
/// added to or deleted by the user without touching the curated starter set.
@Model
final class SavedRecipe {
    var title: String
    var bodyText: String
    /// Raw value of `RecipeCategory`. Stored as String so adding new cases
    /// doesn't break decoding of older saved entries.
    var categoryRaw: String
    var savedAt: Date

    init(
        title: String,
        bodyText: String,
        categoryRaw: String,
        savedAt: Date = .now
    ) {
        self.title = title
        self.bodyText = bodyText
        self.categoryRaw = categoryRaw
        self.savedAt = savedAt
    }
}
