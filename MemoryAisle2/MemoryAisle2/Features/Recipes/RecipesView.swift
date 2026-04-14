import SwiftData
import SwiftUI

struct Ingredient: Identifiable {
    let id = UUID()
    let name: String
    let amount: String
    let prep: String?
}

struct CookingStep: Identifiable {
    let id = UUID()
    let number: Int
    let instruction: String
    let duration: String?
    let tip: String?
}

struct RecipeItem: Identifiable {
    let id = UUID()
    let name: String
    let category: RecipeCategory
    let protein: Int
    let calories: Int
    let prepTime: String
    let cookTime: String
    let servings: Int
    let nauseaSafe: Bool
    let ingredients: [Ingredient]
    let steps: [CookingStep]
    let description: String
    let miraTip: String
}

enum RecipeCategory: String, CaseIterable {
    case breakfast = "Breakfast"
    case lunch = "Lunch"
    case dinner = "Dinner"
    case snack = "Snack"
    case smoothie = "Smoothie"
    case mealPrep = "Meal Prep"

    var icon: String {
        switch self {
        case .breakfast: "sunrise.fill"
        case .lunch: "sun.max.fill"
        case .dinner: "moon.fill"
        case .snack: "leaf.fill"
        case .smoothie: "cup.and.saucer.fill"
        case .mealPrep: "clock.fill"
        }
    }
}

private struct MiraRecipeQuery: Identifiable {
    let id = UUID()
    let text: String
}

struct RecipesView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [UserProfile]
    @State private var selectedCategory: RecipeCategory?
    @State private var selectedRecipe: RecipeItem?
    @State private var selectedSavedRecipe: SavedRecipe?
    @State private var recipeQuery: String = ""
    @State private var miraQuery: MiraRecipeQuery?
    @State private var showReceiptScanner = false
    @FocusState private var inputFocused: Bool

    private var profile: UserProfile? { profiles.first }
    private var isOnMedication: Bool { profile?.medication != nil }

    private var filteredRecipes: [RecipeItem] {
        guard let selectedCategory else { return RecipesSeed.all }
        return RecipesSeed.all.filter { $0.category == selectedCategory }
    }

    private var heroSubtitle: String {
        isOnMedication
            ? "Recipes tuned for GLP-1 · ask Mira for more"
            : "High-protein recipes · ask Mira for more"
    }

    var body: some View {
        VStack(spacing: 0) {
            HeroHeader(title: "Recipes", subtitle: heroSubtitle) {
                HStack(spacing: 8) {
                    IconButton(
                        systemName: "doc.text.viewfinder",
                        accessibilityLabel: "Scan receipt"
                    ) {
                        showReceiptScanner = true
                    }
                    CloseButton(action: { dismiss() })
                }
            }

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 18) {
                    todaysPlan
                    SavedRecipesSection { saved in
                        selectedSavedRecipe = saved
                    }
                    miraSearchBar
                    categoryFilter
                    ForEach(filteredRecipes) { recipe in
                        recipeCard(recipe)
                    }
                    Spacer(minLength: 80)
                }
                .padding(.top, 18)
            }
        }
        .section(.recipes)
        .themeBackground()
        .navigationBarHidden(true)
        .sheet(item: $selectedRecipe) { recipe in
            RecipeDetailView(recipe: recipe)
        }
        .sheet(item: $selectedSavedRecipe) { saved in
            SavedRecipeDetailView(recipe: saved)
        }
        .sheet(item: $miraQuery) { query in
            MiraChatView(autoSendMessage: query.text, mode: .recipeBrowser)
        }
        .sheet(isPresented: $showReceiptScanner) {
            ReceiptScannerView()
        }
    }

    // MARK: - Mira Search Bar

    private var miraSearchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15))
                .foregroundStyle(SectionPalette.primary(.recipes, for: scheme).opacity(0.75))

            TextField("Browse more recipes with Mira…", text: $recipeQuery)
                .font(Typography.bodyLarge)
                .foregroundStyle(Theme.Text.primary)
                .focused($inputFocused)
                .submitLabel(.search)
                .onSubmit { askMira(recipeQuery) }

            if !recipeQuery.isEmpty {
                Button {
                    askMira(recipeQuery)
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(SectionPalette.primary(.recipes, for: scheme))
                }
                .accessibilityLabel("Ask Mira")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Theme.Section.glass(.recipes, for: scheme))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Theme.Section.border(.recipes, for: scheme), lineWidth: Theme.glassBorderWidth)
        )
        .padding(.horizontal, 20)
    }

    private func askMira(_ prompt: String) {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        HapticManager.light()
        inputFocused = false
        recipeQuery = ""
        miraQuery = MiraRecipeQuery(text: "Suggest a recipe: \(trimmed)")
    }

    // MARK: - Today's Plan

    private var todaysPlan: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("A FEW OF OUR FAVORITES")
                .font(Typography.label)
                .foregroundStyle(SectionPalette.soft(.recipes))
                .tracking(1.2)
                .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    todayMealCard("8:30 AM", name: "Protein Oats", protein: 32, icon: "sunrise.fill")
                    todayMealCard("12:30 PM", name: "Chicken Bowl", protein: 42, icon: "sun.max.fill")
                    todayMealCard("6:00 PM", name: "Salmon Dinner", protein: 38, icon: "moon.fill")
                    todayMealCard("Snack", name: "Yogurt + Seeds", protein: 28, icon: "leaf.fill")
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private func todayMealCard(_ time: String, name: String, protein: Int, icon: String) -> some View {
        SectionCard(section: .home) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: icon)
                        .font(.system(size: 10))
                        .foregroundStyle(SectionPalette.primary(.home, for: scheme).opacity(0.75))
                    Text(time)
                        .font(Typography.caption)
                        .foregroundStyle(Theme.Text.tertiary(for: scheme))
                }
                Text(name)
                    .font(Typography.bodyMediumBold)
                    .foregroundStyle(Theme.Text.primary)
                    .lineLimit(1)
                Text("\(protein)g protein")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(SectionPalette.primary(.home, for: scheme))
            }
            .padding(12)
            .frame(width: 140, alignment: .leading)
        }
    }

    // MARK: - Category Filter

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                categoryChip(nil, label: "All")
                ForEach(RecipeCategory.allCases, id: \.self) { cat in
                    categoryChip(cat, label: cat.rawValue)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func categoryChip(_ category: RecipeCategory?, label: String) -> some View {
        let isSelected = selectedCategory == category

        return Button {
            HapticManager.selection()
            withAnimation(.easeOut(duration: 0.15)) {
                selectedCategory = category
            }
        } label: {
            Text(label)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(
                    isSelected
                        ? Color.white
                        : SectionPalette.primary(.recipes, for: scheme)
                )
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(
                        isSelected
                            ? SectionPalette.primary(.recipes, for: scheme)
                            : Theme.Section.glass(.recipes, for: scheme)
                    )
                )
                .overlay(
                    Capsule().stroke(
                        Theme.Section.border(.recipes, for: scheme),
                        lineWidth: Theme.glassBorderWidth
                    )
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Recipe Card

    private func recipeCard(_ recipe: RecipeItem) -> some View {
        InteractiveSectionCard(action: {
            HapticManager.light()
            selectedRecipe = recipe
        }) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: recipe.category.icon)
                        .font(.system(size: 12))
                        .foregroundStyle(SectionPalette.primary(.recipes, for: scheme))
                    Text(recipe.category.rawValue.uppercased())
                        .font(Typography.label)
                        .foregroundStyle(SectionPalette.soft(.recipes))
                        .tracking(1.0)
                    Spacer()
                    if recipe.nauseaSafe {
                        nauseaSafeBadge
                    }
                }

                Text(recipe.name)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Theme.Text.primary)

                Text(recipe.description)
                    .font(Typography.bodySmall)
                    .foregroundStyle(Theme.Text.tertiary(for: scheme))
                    .lineLimit(2)

                HStack(spacing: 14) {
                    macroChip(label: "\(recipe.protein)g protein", color: SectionPalette.primary(.home, for: scheme))
                    macroChip(label: "\(recipe.calories) cal", color: Theme.Text.secondary(for: scheme))
                    Spacer()
                    Text(recipe.prepTime)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.Text.tertiary(for: scheme))
                }
            }
            .padding(16)
        }
        .padding(.horizontal, 20)
    }

    private var nauseaSafeBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 8))
            Text("Nausea-safe")
                .font(.system(size: 9, weight: .medium))
        }
        .foregroundStyle(Theme.Semantic.onTrack(for: scheme))
    }

    private func macroChip(label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 5, height: 5)
            Text(label)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Theme.Text.secondary(for: scheme))
        }
    }
}
