import SwiftData
import SwiftUI

struct MealItem: Identifiable {
    let id = UUID()
    let time: String
    let name: String
    let protein: Int
    let calories: Int
    let prepTime: String
    let status: PillStatus
    let description: String
}

struct MealsView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]

    private var profile: UserProfile? { profiles.first }

    private var meals: [MealItem] {
        let mode = profile?.productMode ?? .everyday

        switch mode {
        case .sensitiveStomach:
            return [
                MealItem(time: "8:30 AM", name: "Banana Oat Smoothie", protein: 18, calories: 280, prepTime: "3 min", status: .nauseaSafe, description: "Gentle on the stomach, easy to sip"),
                MealItem(time: "12:00 PM", name: "Plain Rice with Soft-Boiled Egg", protein: 14, calories: 320, prepTime: "10 min", status: .nauseaSafe, description: "Bland, easy to digest, high protein"),
                MealItem(time: "3:00 PM", name: "Greek Yogurt + Honey", protein: 20, calories: 180, prepTime: "1 min", status: .nauseaSafe, description: "Cool, smooth, probiotic boost"),
                MealItem(time: "6:30 PM", name: "Chicken Broth with Toast", protein: 12, calories: 200, prepTime: "5 min", status: .nauseaSafe, description: "Warm, hydrating, settles the stomach"),
            ]
        case .musclePreservation, .trainingPerformance:
            return [
                MealItem(time: "7:30 AM", name: "Protein Overnight Oats", protein: 35, calories: 420, prepTime: "5 min prep", status: .onTrack, description: "Greek yogurt base, hemp seeds, berries"),
                MealItem(time: "12:00 PM", name: "Grilled Chicken Power Bowl", protein: 45, calories: 580, prepTime: "15 min", status: .neutral, description: "Rice, chicken breast, avocado, greens"),
                MealItem(time: "3:30 PM", name: "Post-Workout Shake", protein: 30, calories: 280, prepTime: "2 min", status: .neutral, description: "Whey protein, banana, almond milk"),
                MealItem(time: "7:00 PM", name: "Salmon with Sweet Potato", protein: 38, calories: 520, prepTime: "25 min", status: .neutral, description: "Omega-3 rich, complex carbs for recovery"),
            ]
        default:
            return [
                MealItem(time: "8:30 AM", name: "Protein Overnight Oats", protein: 32, calories: 380, prepTime: "5 min prep", status: .onTrack, description: "Greek yogurt, chia seeds, berries"),
                MealItem(time: "12:30 PM", name: "Grilled Chicken Bowl", protein: 42, calories: 520, prepTime: "15 min", status: .neutral, description: "Quinoa, roasted vegetables, lemon tahini"),
                MealItem(time: "6:00 PM", name: "Salmon with Vegetables", protein: 38, calories: 480, prepTime: "25 min", status: .neutral, description: "Roasted broccoli, brown rice"),
                MealItem(time: "Snack", name: "Greek Yogurt + Hemp Seeds", protein: 28, calories: 240, prepTime: "2 min", status: .nauseaSafe, description: "Quick protein boost, nausea-friendly"),
            ]
        }
    }

    private var totalProtein: Int { meals.reduce(0) { $0 + $1.protein } }
    private var totalCal: Int { meals.reduce(0) { $0 + $1.calories } }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.md) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text("Today's Meals")
                            .font(Typography.displaySmall)
                            .foregroundStyle(Theme.Text.primary)
                        Text("\(totalProtein)g protein  ·  \(totalCal) cal")
                            .font(Typography.monoSmall)
                            .foregroundStyle(Theme.Text.secondary(for: scheme))
                    }
                    Spacer()
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.top, Theme.Spacing.sm)

                // Mode badge
                if let mode = profile?.productMode {
                    HStack {
                        PillBadge(.neutral, label: mode.rawValue)
                        Spacer()
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                }

                // Meal cards
                ForEach(meals) { meal in
                    mealCard(meal)
                }

                Spacer(minLength: 80)
            }
        }
        .themeBackground()
        .navigationBarHidden(true)
    }

    private func mealCard(_ meal: MealItem) -> some View {
        InteractiveGlassCard(action: {}) {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack {
                    Text(meal.time)
                        .font(Typography.caption)
                        .foregroundStyle(Theme.Text.tertiary(for: scheme))
                    Spacer()
                    PillBadge(meal.status)
                }

                Text(meal.name)
                    .font(Typography.bodyLargeBold)
                    .foregroundStyle(Theme.Text.primary)

                Text(meal.description)
                    .font(Typography.bodySmall)
                    .foregroundStyle(Theme.Text.secondary(for: scheme))

                HStack(spacing: Theme.Spacing.md) {
                    macroLabel("Protein", value: "\(meal.protein)g", category: .protein)
                    macroLabel("Cal", value: "\(meal.calories)", category: .calories)
                    Spacer()
                    Text(meal.prepTime)
                        .font(Typography.caption)
                        .foregroundStyle(Theme.Text.tertiary(for: scheme))
                }
            }
            .padding(Theme.Spacing.md)
        }
        .padding(.horizontal, Theme.Spacing.md)
    }

    private func macroLabel(_ label: String, value: String, category: ProgressCategory) -> some View {
        HStack(spacing: Theme.Spacing.xs) {
            Circle()
                .fill(category.color(for: scheme))
                .frame(width: 6, height: 6)
            Text(value)
                .font(Typography.monoSmall)
                .foregroundStyle(Theme.Text.primary)
        }
    }
}
