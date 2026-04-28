import SwiftUI

/// Three-stat row used as the recap header on the night-mode Meals tab.
/// Renders PROTEIN / CALORIES / MEALS bracketed by hairlines. Values come
/// from the actual `MealPlan.meals` for the selected day.
struct DailyTotalsRow: View {
    let proteinGrams: Int
    let calories: Int
    let mealsCompleted: Int
    let mealsTotal: Int

    var body: some View {
        VStack(spacing: 0) {
            HairlineDivider()
            HStack(spacing: 22) {
                TotalsStat(label: "PROTEIN", value: "\(proteinGrams)", unit: "g")
                TotalsStat(label: "CALORIES", value: "\(calories)", unit: nil)
                TotalsStat(label: "MEALS", value: "\(mealsCompleted)", unit: "/\(mealsTotal)")
            }
            .padding(.vertical, 14)
            HairlineDivider()
        }
    }
}
