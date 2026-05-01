import Foundation
import SwiftData

/// A favorited item the user keeps in their personal collection. Started as
/// recipes saved from Mira chat (`kind = .recipe`); extended 2026-05-01 to
/// also hold favorited Mira meal suggestions from the Today dashboard
/// (`kind = .suggestion`). One model + one Favorites view shows both.
///
/// New fields are all optional so the SwiftData migration is lightweight —
/// existing rows decode with `kindRaw == nil` and are treated as `.recipe`.
@Model
final class SavedRecipe {
    var title: String
    var bodyText: String
    /// Raw value of `RecipeCategory`. Stored as String so adding new cases
    /// doesn't break decoding of older saved entries.
    var categoryRaw: String
    var savedAt: Date

    /// Discriminator. `nil` for legacy rows (interpret as `.recipe`).
    var kindRaw: String?

    /// Macro snapshot used by `.suggestion` rows so the Favorites list can
    /// render macros without re-hitting Bedrock. Always nil for `.recipe`
    /// rows — recipe macros live inside `bodyText`.
    var savedCalories: Int?
    var savedProteinG: Int?
    var savedFatG: Int?
    var savedCarbsG: Int?

    init(
        title: String,
        bodyText: String,
        categoryRaw: String,
        savedAt: Date = .now,
        kindRaw: String? = nil,
        savedCalories: Int? = nil,
        savedProteinG: Int? = nil,
        savedFatG: Int? = nil,
        savedCarbsG: Int? = nil
    ) {
        self.title = title
        self.bodyText = bodyText
        self.categoryRaw = categoryRaw
        self.savedAt = savedAt
        self.kindRaw = kindRaw
        self.savedCalories = savedCalories
        self.savedProteinG = savedProteinG
        self.savedFatG = savedFatG
        self.savedCarbsG = savedCarbsG
    }

    enum Kind: String, Sendable {
        case recipe, suggestion
    }

    /// Resolved kind. Legacy rows (`kindRaw == nil`) are recipes.
    var kind: Kind {
        kindRaw.flatMap(Kind.init(rawValue:)) ?? .recipe
    }
}
