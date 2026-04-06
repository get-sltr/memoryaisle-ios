import SwiftData
import SwiftUI

struct GroceryCategory: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    var items: [GroceryItem]
}

struct GroceryItem: Identifiable {
    let id = UUID()
    let name: String
    let quantity: String
    let proteinPer: String?
    var isChecked: Bool = false
}

struct GroceryListView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [UserProfile]

    @State private var categories: [GroceryCategory]

    private var profile: UserProfile? { profiles.first }

    init() {
        _categories = State(initialValue: Self.defaultList())
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Grocery List")
                    .font(Typography.displaySmall)
                    .foregroundStyle(Theme.Text.primary)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(Theme.Text.tertiary(for: scheme))
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.top, Theme.Spacing.md)
            .padding(.bottom, Theme.Spacing.sm)

            ScrollView {
                VStack(spacing: Theme.Spacing.md) {
                    ForEach(Array(categories.enumerated()), id: \.element.id) { catIndex, category in
                        GlassCard {
                            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                                HStack(spacing: Theme.Spacing.sm) {
                                    Image(systemName: category.icon)
                                        .font(Typography.bodyMedium)
                                        .foregroundStyle(Theme.Accent.primary(for: scheme))
                                    Text(category.name)
                                        .font(Typography.bodyMediumBold)
                                        .foregroundStyle(Theme.Text.primary)
                                }

                                ForEach(Array(category.items.enumerated()), id: \.element.id) { itemIndex, item in
                                    Button {
                                        HapticManager.selection()
                                        categories[catIndex].items[itemIndex].isChecked.toggle()
                                    } label: {
                                        HStack {
                                            Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                                                .foregroundStyle(
                                                    item.isChecked
                                                        ? Theme.Semantic.onTrack(for: scheme)
                                                        : Theme.Text.tertiary(for: scheme)
                                                )
                                                .font(.system(size: 20))

                                            Text(item.name)
                                                .font(Typography.bodyMedium)
                                                .foregroundStyle(
                                                    item.isChecked
                                                        ? Theme.Text.tertiary(for: scheme)
                                                        : Theme.Text.primary
                                                )
                                                .strikethrough(item.isChecked)

                                            Spacer()

                                            VStack(alignment: .trailing, spacing: 2) {
                                                Text(item.quantity)
                                                    .font(Typography.caption)
                                                    .foregroundStyle(Theme.Text.secondary(for: scheme))
                                                if let protein = item.proteinPer {
                                                    Text(protein)
                                                        .font(Typography.caption)
                                                        .foregroundStyle(Theme.Semantic.protein(for: scheme))
                                                }
                                            }
                                        }
                                        .padding(.vertical, Theme.Spacing.xs)
                                    }
                                }
                            }
                            .padding(Theme.Spacing.md)
                        }
                        .padding(.horizontal, Theme.Spacing.md)
                    }

                    Spacer(minLength: 40)
                }
            }
        }
        .themeBackground()
    }

    // MARK: - Default Grocery List

    private static func defaultList() -> [GroceryCategory] {
        [
            GroceryCategory(name: "Protein", icon: "flame.fill", items: [
                GroceryItem(name: "Chicken breast", quantity: "2 lbs", proteinPer: "31g/4oz"),
                GroceryItem(name: "Salmon fillets", quantity: "1 lb", proteinPer: "23g/4oz"),
                GroceryItem(name: "Eggs (dozen)", quantity: "1", proteinPer: "6g each"),
                GroceryItem(name: "Greek yogurt", quantity: "32 oz", proteinPer: "15g/cup"),
                GroceryItem(name: "Whey protein", quantity: "1 tub", proteinPer: "25g/scoop"),
            ]),
            GroceryCategory(name: "Grains & Carbs", icon: "leaf.fill", items: [
                GroceryItem(name: "Brown rice", quantity: "2 lbs", proteinPer: nil),
                GroceryItem(name: "Quinoa", quantity: "1 lb", proteinPer: "8g/cup"),
                GroceryItem(name: "Oats", quantity: "18 oz", proteinPer: "5g/cup"),
                GroceryItem(name: "Sweet potatoes", quantity: "3", proteinPer: nil),
            ]),
            GroceryCategory(name: "Produce", icon: "carrot.fill", items: [
                GroceryItem(name: "Broccoli", quantity: "2 heads", proteinPer: nil),
                GroceryItem(name: "Spinach", quantity: "1 bag", proteinPer: nil),
                GroceryItem(name: "Bananas", quantity: "6", proteinPer: nil),
                GroceryItem(name: "Berries (mixed)", quantity: "1 pint", proteinPer: nil),
                GroceryItem(name: "Avocados", quantity: "3", proteinPer: nil),
                GroceryItem(name: "Ginger root", quantity: "1", proteinPer: nil),
            ]),
            GroceryCategory(name: "Pantry", icon: "bag.fill", items: [
                GroceryItem(name: "Hemp seeds", quantity: "8 oz", proteinPer: "10g/3tbsp"),
                GroceryItem(name: "Almond butter", quantity: "1 jar", proteinPer: "7g/2tbsp"),
                GroceryItem(name: "Chia seeds", quantity: "6 oz", proteinPer: "5g/2tbsp"),
                GroceryItem(name: "Ginger tea bags", quantity: "1 box", proteinPer: nil),
            ]),
        ]
    }
}
