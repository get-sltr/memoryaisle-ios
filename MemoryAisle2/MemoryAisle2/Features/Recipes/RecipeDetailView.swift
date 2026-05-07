import SwiftData
import SwiftUI

struct RecipeDetailView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    let recipe: RecipeItem

    // Mira's recipe tips in RecipesSeed are GLP-1-aware (they reference
    // nausea days, appetite, dose timing). Hide the tip card entirely
    // for non-medication users until we have a second set of universal
    // tips. The recipe itself (ingredients, steps, macros) is still
    // fully useful for everyone.
    private var isOnMedication: Bool {
        profiles.first?.medication != nil
    }

    private var heroSubtitle: String {
        var parts: [String] = ["Serves \(recipe.servings)"]
        parts.append("\(recipe.prepTime) prep")
        if !recipe.cookTime.isEmpty && recipe.cookTime != "0" {
            parts.append("\(recipe.cookTime) cook")
        }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        VStack(spacing: 0) {
            HeroHeader(title: recipe.name, subtitle: heroSubtitle) {
                DismissButton(action: { dismiss() })
            }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    description
                    if recipe.nauseaSafe { nauseaSafeBadge }
                    statsRow
                    ingredientsCard
                    stepsCard
                    if isOnMedication {
                        miraTipCard
                    }
                    GlowButton("Log this meal", icon: "checkmark.circle.fill") {
                        MealLogger.log(
                            name: recipe.name,
                            proteinGrams: Double(recipe.protein),
                            caloriesConsumed: Double(recipe.calories),
                            in: modelContext
                        )
                        HapticManager.success()
                        dismiss()
                    }
                    .padding(.horizontal, 32)
                    Spacer(minLength: 40)
                }
                .padding(.top, 20)
            }
        }
        .section(.recipes)
        .themeBackground()
    }

    // MARK: - Description

    private var description: some View {
        Text(recipe.description)
            .font(Typography.bodyMedium)
            .foregroundStyle(Theme.Text.secondary(for: scheme))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 28)
    }

    // MARK: - Nausea-safe badge

    private var nauseaSafeBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 11))
            Text("Nausea-safe")
                .font(Typography.bodySmallBold)
        }
        .foregroundStyle(Theme.Semantic.onTrack(for: scheme))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule().fill(Theme.Semantic.onTrack(for: scheme).opacity(0.12))
        )
        .overlay(
            Capsule().stroke(
                Theme.Semantic.onTrack(for: scheme).opacity(0.30),
                lineWidth: 0.5
            )
        )
    }

    // MARK: - Stats row

    private var statsRow: some View {
        HStack(spacing: 10) {
            StatTile(label: "Protein", value: "\(recipe.protein)g")
            StatTile(label: "Calories", value: "\(recipe.calories)")
            StatTile(label: "Time", value: recipe.prepTime, sub: "prep")
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Ingredients

    private var ingredientsCard: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionLabel("INGREDIENTS")
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(recipe.ingredients) { item in
                        ingredientRow(item)
                    }
                }
            }
            .padding(16)
        }
        .padding(.horizontal, 20)
    }

    private func ingredientRow(_ item: Ingredient) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(SectionPalette.primary(.recipes, for: scheme).opacity(0.55))
                .frame(width: 5, height: 5)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(item.name)
                        .font(Typography.bodyMedium)
                        .foregroundStyle(Theme.Text.secondary(for: scheme))
                    Spacer()
                    Text(item.amount)
                        .font(Typography.monoSmall)
                        .foregroundStyle(Theme.Text.tertiary(for: scheme))
                }
                if let prep = item.prep {
                    Text(prep)
                        .font(Typography.caption)
                        .foregroundStyle(SectionPalette.soft(.recipes))
                }
            }
        }
    }

    // MARK: - Steps

    private var stepsCard: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionLabel("HOW TO MAKE IT")
                ForEach(recipe.steps) { step in
                    stepRow(step)
                }
            }
            .padding(16)
        }
        .padding(.horizontal, 20)
    }

    private func stepRow(_ step: CookingStep) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 12) {
                Text("\(step.number)")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(SectionPalette.primary(.recipes, for: scheme))
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 4) {
                    Text(step.instruction)
                        .font(Typography.bodyMedium)
                        .foregroundStyle(Theme.Text.primary)

                    if let duration = step.duration {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 10))
                            Text(duration)
                                .font(Typography.caption)
                        }
                        .foregroundStyle(Theme.Text.tertiary(for: scheme))
                    }

                    if let tip = step.tip {
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "lightbulb.fill")
                                .font(.system(size: 10))
                            Text(tip)
                                .font(Typography.bodySmall)
                        }
                        .foregroundStyle(Theme.Semantic.fiber(for: scheme).opacity(0.75))
                        .padding(.top, 2)
                    }
                }
            }

            if step.number < recipe.steps.count {
                Rectangle()
                    .fill(Theme.Section.border(.recipes, for: scheme))
                    .frame(height: 0.5)
                    .padding(.leading, 32)
            }
        }
    }

    // MARK: - Mira tip (violet contrast card inside amber view)

    private var miraTipCard: some View {
        SectionCard(section: .home) {
            HStack(alignment: .top, spacing: 12) {
                MiraWaveform(state: .idle, size: .hero)
                    .scaleEffect(0.35, anchor: .leading)
                    .frame(width: 30, height: 14)
                    .padding(.top, 2)

                Text(recipe.miraTip)
                    .font(Typography.bodySmall)
                    .foregroundStyle(Theme.Text.secondary(for: scheme))
            }
            .padding(16)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(Typography.label)
            .foregroundStyle(SectionPalette.soft(.recipes))
            .tracking(1.2)
    }
}
