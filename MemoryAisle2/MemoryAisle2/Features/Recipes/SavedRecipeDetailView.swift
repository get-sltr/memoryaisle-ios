import SwiftData
import SwiftUI

/// Read-only detail sheet for a `SavedRecipe`. Renders Mira's original
/// response text as-is and offers a delete affordance in the top right.
struct SavedRecipeDetailView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let recipe: SavedRecipe
    @State private var showDeleteConfirm = false

    private var category: RecipeCategory {
        RecipeCategory(rawValue: recipe.categoryRaw) ?? .dinner
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    metaRow
                    Text(recipe.bodyText)
                        .font(Typography.bodyMedium)
                        .foregroundStyle(Theme.Text.primary)
                        .lineSpacing(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(20)
            }
        }
        .section(.recipes)
        .themeBackground()
        .confirmationDialog(
            "Delete this recipe?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                modelContext.delete(recipe)
                try? modelContext.save()
                HapticManager.success()
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            CloseButton(action: { dismiss() })
            Spacer()
            Text(recipe.title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.Text.primary)
                .lineLimit(1)
            Spacer()
            Button {
                showDeleteConfirm = true
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.Semantic.fiber(for: scheme))
                    .frame(width: 36, height: 36)
                    .background(Theme.Surface.glass(for: scheme))
                    .clipShape(Circle())
                    .overlay(
                        Circle().stroke(
                            Theme.Border.glass(for: scheme),
                            lineWidth: Theme.glassBorderWidth
                        )
                    )
            }
            .accessibilityLabel("Delete recipe")
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }

    private var metaRow: some View {
        HStack(spacing: 8) {
            Image(systemName: category.icon)
                .font(.system(size: 12))
                .foregroundStyle(SectionPalette.primary(.recipes, for: scheme))
            Text(category.rawValue.uppercased())
                .font(Typography.label)
                .foregroundStyle(SectionPalette.soft(.recipes))
                .tracking(1.0)
            Spacer()
            Text(recipe.savedAt.formatted(.dateTime.month().day().year()))
                .font(Typography.caption)
                .foregroundStyle(Theme.Text.tertiary(for: scheme))
        }
    }
}
