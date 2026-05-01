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
    @State private var groceryFeedback: String?

    private var category: RecipeCategory {
        RecipeCategory(rawValue: recipe.categoryRaw) ?? .dinner
    }

    /// Non-empty ingredient list for `.suggestion` rows. Recipe rows always
    /// return nil — their ingredients are baked into `bodyText` and aren't
    /// machine-extractable without the heuristic, which we don't run here.
    private var suggestionIngredients: [String]? {
        guard recipe.kind == .suggestion,
              let items = recipe.savedIngredients,
              !items.isEmpty
        else { return nil }
        return items
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    metaRow

                    if recipe.kind == .suggestion, let line = suggestionMacroLine {
                        Text(line)
                            .font(Typography.label)
                            .foregroundStyle(SectionPalette.soft(.recipes))
                            .tracking(1.0)
                    }

                    Text(recipe.bodyText)
                        .font(Typography.bodyMedium)
                        .foregroundStyle(Theme.Text.primary)
                        .lineSpacing(4)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let ingredients = suggestionIngredients {
                        ingredientsSection(ingredients)
                        addToGroceryButton(ingredients)
                    }
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
        .alert(
            "Grocery list",
            isPresented: Binding(
                get: { groceryFeedback != nil },
                set: { if !$0 { groceryFeedback = nil } }
            ),
            presenting: groceryFeedback
        ) { _ in
            Button("OK", role: .cancel) { groceryFeedback = nil }
        } message: { text in
            Text(text)
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

    /// Macro snapshot rendered as "~520 CAL · 38G PROTEIN · 14G FAT" for
    /// `.suggestion` rows. Returns nil when none of the macro fields were
    /// captured (legacy rows, or older recommendations that didn't ship
    /// with macros).
    private var suggestionMacroLine: String? {
        var parts: [String] = []
        if let cal = recipe.savedCalories { parts.append("~\(cal) CAL") }
        if let p = recipe.savedProteinG { parts.append("\(p)G PROTEIN") }
        if let f = recipe.savedFatG { parts.append("\(f)G FAT") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    // MARK: - Ingredients (suggestion rows only)

    private func ingredientsSection(_ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("INGREDIENTS")
                .font(Typography.label)
                .foregroundStyle(SectionPalette.soft(.recipes))
                .tracking(1.2)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(SectionPalette.primary(.recipes, for: scheme).opacity(0.55))
                            .frame(width: 5, height: 5)
                            .padding(.top, 7)
                        Text(item)
                            .font(Typography.bodyMedium)
                            .foregroundStyle(Theme.Text.secondary(for: scheme))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    private func addToGroceryButton(_ items: [String]) -> some View {
        Button {
            addIngredientsToGrocery(items)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "cart.badge.plus")
                    .font(.system(size: 13, weight: .semibold))
                Text("Add to grocery list")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                Capsule().fill(SectionPalette.primary(.recipes, for: scheme))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add ingredients to grocery list")
        .padding(.top, 4)
    }

    private func addIngredientsToGrocery(_ items: [String]) {
        let result = GroceryAdder.add(items, in: modelContext)
        do {
            try modelContext.save()
        } catch {
            groceryFeedback = "Couldn't save: \(error.localizedDescription)"
            return
        }
        HapticManager.success()
        if result.added.isEmpty && !result.skipped.isEmpty {
            groceryFeedback = "Already on your list."
        } else if result.skipped.isEmpty {
            let n = result.added.count
            groceryFeedback = "Added \(n) ingredient\(n == 1 ? "" : "s") to your grocery list."
        } else {
            groceryFeedback = "Added \(result.added.count). \(result.skipped.count) already on your list."
        }
    }
}
