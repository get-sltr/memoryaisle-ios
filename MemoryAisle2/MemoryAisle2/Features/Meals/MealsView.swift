import SwiftUI

struct MealsView: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.md) {
                // Header
                HStack {
                    Text("Today's Meals")
                        .font(Typography.displaySmall)
                        .foregroundStyle(Theme.Text.primary)
                    Spacer()
                    GhostButtonCompact("Swap", icon: "arrow.2.squarepath") {}
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.top, Theme.Spacing.sm)

                // Meal cards
                mealCard(
                    time: "8:30 AM",
                    name: "Protein Overnight Oats",
                    protein: 32,
                    calories: 380,
                    prepTime: "5 min prep",
                    status: .onTrack
                )

                mealCard(
                    time: "12:30 PM",
                    name: "Grilled Chicken Power Bowl",
                    protein: 42,
                    calories: 520,
                    prepTime: "15 min",
                    status: .neutral
                )

                mealCard(
                    time: "6:00 PM",
                    name: "Salmon with Roasted Vegetables",
                    protein: 38,
                    calories: 480,
                    prepTime: "25 min",
                    status: .neutral
                )

                mealCard(
                    time: "Snack",
                    name: "Greek Yogurt + Hemp Seeds",
                    protein: 28,
                    calories: 240,
                    prepTime: "2 min",
                    status: .nauseaSafe
                )

                Spacer(minLength: 80)
            }
        }
        .themeBackground()
        .navigationBarHidden(true)
    }

    private func mealCard(
        time: String,
        name: String,
        protein: Int,
        calories: Int,
        prepTime: String,
        status: PillStatus
    ) -> some View {
        InteractiveGlassCard(action: {}) {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack {
                    Text(time)
                        .font(Typography.caption)
                        .foregroundStyle(Theme.Text.tertiary(for: scheme))
                    Spacer()
                    PillBadge(status)
                }

                Text(name)
                    .font(Typography.bodyLargeBold)
                    .foregroundStyle(Theme.Text.primary)

                HStack(spacing: Theme.Spacing.md) {
                    macroLabel("Protein", value: "\(protein)g", category: .protein)
                    macroLabel("Cal", value: "\(calories)", category: .calories)

                    Spacer()

                    Text(prepTime)
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
            Text("\(value)")
                .font(Typography.monoSmall)
                .foregroundStyle(Theme.Text.primary)
        }
    }
}
