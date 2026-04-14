import SwiftData
import SwiftUI

/// "Saved by you" section that lives at the top of `RecipesView` between the
/// today's plan strip and the Mira search bar. Hides itself entirely when the
/// user has not saved anything yet, so the Recipes page still feels curated
/// for new users instead of empty.
struct SavedRecipesSection: View {
    @Environment(\.colorScheme) private var scheme
    @Query(sort: \SavedRecipe.savedAt, order: .reverse) private var savedRecipes: [SavedRecipe]

    let onSelect: (SavedRecipe) -> Void

    var body: some View {
        if savedRecipes.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 10) {
                header

                LazyVStack(spacing: 10) {
                    ForEach(savedRecipes) { recipe in
                        savedCard(recipe)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private var header: some View {
        HStack {
            Text("SAVED BY YOU")
                .font(Typography.label)
                .foregroundStyle(SectionPalette.soft(.recipes))
                .tracking(1.2)
            Spacer()
            Text("\(savedRecipes.count)")
                .font(Typography.label)
                .foregroundStyle(Theme.Text.tertiary(for: scheme))
        }
        .padding(.horizontal, 20)
    }

    private func savedCard(_ recipe: SavedRecipe) -> some View {
        let category = RecipeCategory(rawValue: recipe.categoryRaw) ?? .dinner
        return InteractiveSectionCard(action: {
            HapticManager.light()
            onSelect(recipe)
        }) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(SectionPalette.primary(.recipes, for: scheme))
                    Text(category.rawValue.uppercased())
                        .font(Typography.label)
                        .foregroundStyle(SectionPalette.soft(.recipes))
                        .tracking(1.0)
                    Spacer()
                    Text(recipe.savedAt.formatted(.dateTime.month().day()))
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.Text.tertiary(for: scheme))
                }

                Text(recipe.title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.Text.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
