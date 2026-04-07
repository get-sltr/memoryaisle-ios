import SwiftData
import SwiftUI

struct RecipeItem: Identifiable {
    let id = UUID()
    let name: String
    let category: RecipeCategory
    let protein: Int
    let calories: Int
    let prepTime: String
    let servings: Int
    let nauseaSafe: Bool
    let ingredients: [String]
    let description: String
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

struct RecipesView: View {
    @Environment(\.colorScheme) private var scheme
    @Query private var profiles: [UserProfile]
    @State private var selectedCategory: RecipeCategory?
    @State private var selectedRecipe: RecipeItem?
    @State private var showReceiptScanner = false

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                // Header
                HStack {
                    Text("Recipes")
                        .font(.system(size: 26, weight: .light, design: .serif))
                        .foregroundStyle(.white)
                        .tracking(0.3)
                    Spacer()
                    Button {
                        showReceiptScanner = true
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "doc.text.viewfinder")
                                .font(.system(size: 12))
                            Text("Receipt")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(Color(hex: 0xA78BFA).opacity(0.7))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(hex: 0xA78BFA).opacity(0.08))
                        .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                // Today's plan
                todaysPlan

                // Category filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        categoryChip(nil, label: "All")
                        ForEach(RecipeCategory.allCases, id: \.self) { cat in
                            categoryChip(cat, label: cat.rawValue)
                        }
                    }
                    .padding(.horizontal, 20)
                }

                // Recipe library
                let filtered = selectedCategory == nil ? allRecipes : allRecipes.filter { $0.category == selectedCategory }

                ForEach(filtered) { recipe in
                    recipeCard(recipe)
                }

                Spacer(minLength: 80)
            }
        }
        .themeBackground()
        .navigationBarHidden(true)
        .sheet(item: $selectedRecipe) { recipe in
            RecipeDetailView(recipe: recipe)
        }
        .sheet(isPresented: $showReceiptScanner) {
            ReceiptScannerView()
        }
    }

    // MARK: - Today's Plan

    private var todaysPlan: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TODAY'S PLAN")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.25))
                .tracking(1.2)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    todayMealCard("8:30 AM", name: "Protein Oats", protein: 32, icon: "sunrise.fill")
                    todayMealCard("12:30 PM", name: "Chicken Bowl", protein: 42, icon: "sun.max.fill")
                    todayMealCard("6:00 PM", name: "Salmon Dinner", protein: 38, icon: "moon.fill")
                    todayMealCard("Snack", name: "Yogurt + Seeds", protein: 28, icon: "leaf.fill")
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private func todayMealCard(_ time: String, name: String, protein: Int, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                    .foregroundStyle(Color(hex: 0xA78BFA).opacity(0.5))
                Text(time)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.3))
            }
            Text(name)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)
            Text("\(protein)g protein")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Color(hex: 0xA78BFA).opacity(0.6))
        }
        .padding(12)
        .frame(width: 140)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.white.opacity(0.06), lineWidth: 0.5)
        )
    }

    // MARK: - Category Chip

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
                .foregroundStyle(isSelected ? .white : .white.opacity(0.4))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(isSelected ? Color(hex: 0xA78BFA).opacity(0.2) : .white.opacity(0.04))
                )
                .overlay(
                    Capsule().stroke(isSelected ? Color(hex: 0xA78BFA).opacity(0.3) : .clear, lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Recipe Card

    private func recipeCard(_ recipe: RecipeItem) -> some View {
        Button {
            HapticManager.light()
            selectedRecipe = recipe
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: recipe.category.icon)
                        .font(.system(size: 11))
                        .foregroundStyle(Color(hex: 0xA78BFA).opacity(0.5))
                    Text(recipe.category.rawValue.uppercased())
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.25))
                        .tracking(0.8)
                    Spacer()
                    if recipe.nauseaSafe {
                        HStack(spacing: 3) {
                            Image(systemName: "leaf.fill")
                                .font(.system(size: 8))
                            Text("Nausea-safe")
                                .font(.system(size: 9, weight: .medium))
                        }
                        .foregroundStyle(Color(hex: 0x34D399).opacity(0.7))
                    }
                }

                Text(recipe.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)

                Text(recipe.description)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.35))
                    .lineLimit(2)

                HStack(spacing: 14) {
                    HStack(spacing: 3) {
                        Circle().fill(Color(hex: 0xA78BFA)).frame(width: 4, height: 4)
                        Text("\(recipe.protein)g protein")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    HStack(spacing: 3) {
                        Circle().fill(.white.opacity(0.2)).frame(width: 4, height: 4)
                        Text("\(recipe.calories) cal")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.35))
                    }
                    Spacer()
                    Text(recipe.prepTime)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.2))
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.white.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(.white.opacity(0.06), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
    }

    // MARK: - Recipe Data

    private var allRecipes: [RecipeItem] {
        [
            RecipeItem(name: "Protein Overnight Oats", category: .breakfast, protein: 32, calories: 380, prepTime: "5 min", servings: 1, nauseaSafe: true, ingredients: ["Greek yogurt", "Oats", "Chia seeds", "Hemp seeds", "Berries", "Honey"], description: "High-protein breakfast that preps in minutes. Greek yogurt base with seeds for extra protein."),
            RecipeItem(name: "Egg White Veggie Scramble", category: .breakfast, protein: 28, calories: 220, prepTime: "8 min", servings: 1, nauseaSafe: true, ingredients: ["Egg whites", "Spinach", "Bell pepper", "Mushrooms", "Feta"], description: "Light and protein-packed. Perfect for low-appetite mornings."),
            RecipeItem(name: "Grilled Chicken Power Bowl", category: .lunch, protein: 45, calories: 580, prepTime: "15 min", servings: 1, nauseaSafe: false, ingredients: ["Chicken breast", "Brown rice", "Avocado", "Greens", "Lemon tahini"], description: "The ultimate muscle-preserving lunch. 45g protein in one bowl."),
            RecipeItem(name: "Tuna Lettuce Wraps", category: .lunch, protein: 35, calories: 280, prepTime: "5 min", servings: 2, nauseaSafe: true, ingredients: ["Canned tuna", "Lettuce", "Greek yogurt", "Celery", "Lemon"], description: "Low-cal, high-protein, nausea-friendly. No cooking required."),
            RecipeItem(name: "Salmon with Sweet Potato", category: .dinner, protein: 38, calories: 520, prepTime: "25 min", servings: 1, nauseaSafe: false, ingredients: ["Salmon fillet", "Sweet potato", "Broccoli", "Olive oil", "Lemon"], description: "Omega-3 rich dinner with complex carbs for recovery."),
            RecipeItem(name: "Turkey Meatballs + Zoodles", category: .dinner, protein: 42, calories: 380, prepTime: "20 min", servings: 2, nauseaSafe: false, ingredients: ["Ground turkey", "Zucchini", "Marinara", "Parmesan", "Garlic"], description: "Low-carb, high-protein dinner. Freeze extra meatballs for meal prep."),
            RecipeItem(name: "Greek Yogurt Parfait", category: .snack, protein: 24, calories: 220, prepTime: "2 min", servings: 1, nauseaSafe: true, ingredients: ["Greek yogurt", "Hemp seeds", "Berries", "Honey"], description: "Quick protein hit. Probiotics help with GI comfort."),
            RecipeItem(name: "Cottage Cheese + Fruit", category: .snack, protein: 22, calories: 180, prepTime: "1 min", servings: 1, nauseaSafe: true, ingredients: ["Cottage cheese", "Pineapple", "Cinnamon"], description: "Simple, cold, easy on the stomach. 22g protein per serving."),
            RecipeItem(name: "High-Protein Green Smoothie", category: .smoothie, protein: 30, calories: 320, prepTime: "3 min", servings: 1, nauseaSafe: true, ingredients: ["Protein powder", "Spinach", "Banana", "Almond milk", "Peanut butter"], description: "Drinkable protein for low-appetite days. Greens for micronutrients."),
            RecipeItem(name: "Berry Protein Shake", category: .smoothie, protein: 28, calories: 250, prepTime: "2 min", servings: 1, nauseaSafe: true, ingredients: ["Whey protein", "Mixed berries", "Almond milk", "Ice"], description: "Post-workout recovery. Fast, cold, easy to get down."),
            RecipeItem(name: "Chicken + Rice Meal Prep", category: .mealPrep, protein: 40, calories: 480, prepTime: "45 min", servings: 5, nauseaSafe: false, ingredients: ["Chicken thighs", "Rice", "Broccoli", "Soy sauce", "Sesame oil"], description: "5 days of lunches in 45 minutes. 40g protein per container."),
            RecipeItem(name: "Egg Muffin Cups", category: .mealPrep, protein: 18, calories: 160, prepTime: "25 min", servings: 6, nauseaSafe: true, ingredients: ["Eggs", "Turkey sausage", "Spinach", "Cheese", "Bell pepper"], description: "Grab-and-go breakfast. Reheat in 30 seconds. Freeze for weeks."),
        ]
    }
}
