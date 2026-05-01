import SwiftData
import SwiftUI

/// The "Recommended for lunch" block in the gold zone of the dashboard.
/// Carousel of meal options with three pop-out card actions (Log / Order / Mira).
struct MiraRecommendationView: View {
    let recommendations: [MealRecommendation]
    let window: MealWindow
    @Binding var currentIndex: Int
    let onAction: (DashboardCard) -> Void

    @Environment(\.modelContext) private var modelContext
    @Query private var saved: [SavedRecipe]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            title
            macros
            actions
        }
        .padding(.vertical, 16)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.Editorial.hairline).frame(height: 0.5)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.Editorial.hairline).frame(height: 0.5)
        }
        .padding(.top, 22)
    }

    // MARK: Subviews

    private var header: some View {
        HStack(alignment: .center) {
            Text("— \(window.eyebrowText)")
                .font(Theme.Editorial.Typography.capsBold(8))
                .tracking(2.2)
                .foregroundStyle(Theme.Editorial.onSurface)

            Spacer()

            HStack(spacing: 14) {
                Button(action: prev) {
                    Text("‹")
                        .font(.system(size: 16, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Theme.Editorial.onSurface)
                        .padding(.horizontal, 4)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Previous meal")

                Text(countLabel)
                    .font(Theme.Editorial.Typography.caps(8, weight: .semibold))
                    .tracking(1.8)
                    .foregroundStyle(Theme.Editorial.onSurfaceMuted)
                    .monospacedDigit()

                Button(action: next) {
                    Text("›")
                        .font(.system(size: 16, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Theme.Editorial.onSurface)
                        .padding(.horizontal, 4)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Next meal")

                heartButton
            }
        }
    }

    /// Heart toggle for the current recommendation. Saved entries land in
    /// the Favorites menu (`SavedRecipe` with `kind == .suggestion`).
    private var heartButton: some View {
        let savedAlready = isCurrentSaved
        return Button {
            HapticManager.light()
            toggleFavorite()
        } label: {
            Image(systemName: savedAlready ? "heart.fill" : "heart")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Theme.Editorial.onSurface)
                .padding(.horizontal, 4)
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(savedAlready ? "Remove from favorites" : "Add to favorites")
    }

    private var title: some View {
        Text(safeRecommendation.name)
            .font(Theme.Editorial.Typography.mealName())
            .italic()
            .foregroundStyle(Theme.Editorial.onSurface)
            .lineLimit(2)
            .id(currentIndex)
            .transition(.opacity)
    }

    private var macros: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(safeRecommendation.macroLine)
            Text(safeRecommendation.reasoning.uppercased())
        }
        .font(Theme.Editorial.Typography.caps(9, weight: .semibold))
        .tracking(1.6)
        .foregroundStyle(Theme.Editorial.onSurfaceMuted)
        .id("macros-\(currentIndex)")
        .transition(.opacity)
    }

    private var actions: some View {
        HStack(spacing: 18) {
            actionButton("→ LOG IT", primary: true) { onAction(.log) }
            actionButton("↗ ORDER IT")              { onAction(.order) }
            actionButton("↪ TELL ME MORE")          { onAction(.mira) }
            Spacer()
        }
    }

    private func actionButton(_ title: String, primary: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Theme.Editorial.Typography.capsBold(9))
                .tracking(1.8)
                .foregroundStyle(Theme.Editorial.onSurface)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Theme.Editorial.onSurface)
                        .frame(height: primary ? 1.2 : 0.5)
                        .offset(y: 3)
                }
        }
        .buttonStyle(.plain)
    }

    // MARK: Helpers

    private var safeRecommendation: MealRecommendation {
        guard !recommendations.isEmpty,
              currentIndex >= 0,
              currentIndex < recommendations.count
        else {
            return MealRecommendation(
                name: "No recommendations available.",
                calories: 0, proteinG: 0, fatG: 0,
                reasoning: "Tap Tell Me More for help."
            )
        }
        return recommendations[currentIndex]
    }

    private var countLabel: String {
        guard !recommendations.isEmpty else { return "00 / 00" }
        let current = String(format: "%02d", currentIndex + 1)
        let total   = String(format: "%02d", recommendations.count)
        return "\(current) / \(total)"
    }

    private func prev() {
        withAnimation(.easeInOut(duration: 0.2)) {
            guard !recommendations.isEmpty else { return }
            currentIndex = (currentIndex - 1 + recommendations.count) % recommendations.count
        }
    }

    private func next() {
        withAnimation(.easeInOut(duration: 0.2)) {
            guard !recommendations.isEmpty else { return }
            currentIndex = (currentIndex + 1) % recommendations.count
        }
    }

    // MARK: Favorites

    /// Match by name + macros. Bedrock regenerates `id` per fetch, so we
    /// can't dedupe on UUID — name + calories + protein is stable enough
    /// for "is this exact suggestion already saved?" without overcounting.
    private func savedEntry(for rec: MealRecommendation) -> SavedRecipe? {
        saved.first { entry in
            entry.kind == .suggestion
                && entry.title == rec.name
                && entry.savedCalories == rec.calories
                && entry.savedProteinG == rec.proteinG
        }
    }

    private var isCurrentSaved: Bool {
        savedEntry(for: safeRecommendation) != nil
    }

    private func toggleFavorite() {
        let rec = safeRecommendation
        if let existing = savedEntry(for: rec) {
            modelContext.delete(existing)
            return
        }
        let entry = SavedRecipe(
            title: rec.name,
            bodyText: rec.reasoning,
            categoryRaw: window.recipeCategoryRaw,
            kindRaw: SavedRecipe.Kind.suggestion.rawValue,
            savedCalories: rec.calories,
            savedProteinG: rec.proteinG,
            savedFatG: rec.fatG,
            savedCarbsG: rec.carbsG,
            savedIngredients: rec.ingredients.isEmpty ? nil : rec.ingredients
        )
        modelContext.insert(entry)
    }
}
