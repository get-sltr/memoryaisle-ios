import SwiftData
import SwiftUI

struct GroceryListScreen: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [UserProfile]
    @Query(sort: \PantryItem.addedDate, order: .reverse) private var pantryItems: [PantryItem]
    @State private var newItemText = ""
    @State private var duplicateItemName: String?
    @FocusState private var inputFocused: Bool

    private var profile: UserProfile? { profiles.first }

    // Group items by category
    private var groupedItems: [(category: PantryCategory, items: [PantryItem])] {
        let grouped = Dictionary(grouping: pantryItems, by: \.category)
        let order: [PantryCategory] = [.protein, .produce, .dairy, .grains, .frozen, .pantryStaple, .snacks, .beverages, .condiments, .other]
        return order.compactMap { cat in
            guard let items = grouped[cat], !items.isEmpty else { return nil }
            return (category: cat, items: items)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button {
                    HapticManager.light()
                    dismiss()
                } label: {
                    OnboardingLogo(size: 72)
                }
                .accessibilityLabel("Close grocery list")

                VStack(alignment: .leading, spacing: 2) {
                    Text(greeting)
                        .font(Typography.bodySmall)
                        .foregroundStyle(Theme.Text.tertiary(for: scheme))
                    Text("Grocery List")
                        .font(.system(size: 22, weight: .light, design: .serif))
                        .foregroundStyle(Theme.Text.primary)
                        .tracking(0.3)
                }
                .padding(.leading, 10)

                Spacer()

                if !pantryItems.isEmpty {
                    Text("\(pantryItems.count)")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(SectionPalette.primary(.home, for: scheme).opacity(0.75))
                        .accessibilityLabel("\(pantryItems.count) items in list")
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 12)

            // List
            if pantryItems.isEmpty {
                emptyState
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        ForEach(groupedItems, id: \.category) { group in
                            categorySection(group.category, items: group.items)
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 100)
                }
            }

            Spacer(minLength: 0)

            // Input bar
            inputBar
        }
        .section(.home)
        .themeBackground()
        .navigationBarHidden(true)
        .alert(
            "Already in your list",
            isPresented: Binding(
                get: { duplicateItemName != nil },
                set: { if !$0 { duplicateItemName = nil } }
            ),
            presenting: duplicateItemName
        ) { _ in
            Button("Add anyway", role: .destructive) {
                forceAddItem()
                duplicateItemName = nil
            }
            Button("Cancel", role: .cancel) {
                duplicateItemName = nil
            }
        } message: { name in
            Text("\(name) is already in your grocery list. Do you want to add another?")
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "cart")
                .font(.system(size: 48))
                .foregroundStyle(SectionPalette.primary(.home, for: scheme).opacity(0.25))

            Text("Your list is empty")
                .font(.system(size: 18, weight: .light, design: .serif))
                .foregroundStyle(Theme.Text.secondary(for: scheme))

            Text("Type below or tap the mic to add items")
                .font(Typography.bodySmall)
                .foregroundStyle(Theme.Text.tertiary(for: scheme))

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Category Section

    private func categorySection(_ category: PantryCategory, items: [PantryItem]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Category header
            HStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(Typography.caption)
                    .foregroundStyle(categoryColor(category))

                Text(category.rawValue.uppercased())
                    .font(Typography.label)
                    .fontWeight(.medium)
                    .foregroundStyle(categoryColor(category).opacity(0.7))
                    .tracking(1)

                Rectangle()
                    .fill(categoryColor(category).opacity(0.1))
                    .frame(height: 0.5)

                Text("\(items.count)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(categoryColor(category).opacity(0.4))
            }
            .padding(.horizontal, 20)

            // Items
            ForEach(items) { item in
                Button {
                    HapticManager.success()
                    withAnimation(.easeOut(duration: 0.25)) {
                        modelContext.delete(item)
                    }
                } label: {
                    HStack(spacing: 12) {
                        Circle()
                            .stroke(categoryColor(item.category).opacity(0.3), lineWidth: 1.5)
                            .frame(width: 22, height: 22)

                        Text(item.name)
                            .font(Typography.bodyMedium)
                            .foregroundStyle(Theme.Text.primary)

                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                }
                .accessibilityLabel("Mark \(item.name) as bought")
            }
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(SectionPalette.primary(.home, for: scheme).opacity(0.75))

            TextField("Add an item…", text: $newItemText)
                .font(Typography.bodyLarge)
                .foregroundStyle(Theme.Text.primary)
                .focused($inputFocused)
                .onSubmit { addItem() }

            if !newItemText.isEmpty {
                Button {
                    addItem()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(SectionPalette.primary(.home, for: scheme))
                }
                .accessibilityLabel("Add item")
            } else {
                Button {
                    inputFocused = true
                } label: {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(SectionPalette.primary(.home, for: scheme).opacity(0.5))
                }
                .accessibilityLabel("Voice input")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(
                    Rectangle()
                        .fill(Theme.Surface.glass(for: scheme))
                )
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Theme.Border.glass(for: scheme))
                        .frame(height: Theme.glassBorderWidth)
                }
        )
    }

    // MARK: - Helpers

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        if hour < 12 { return "Good morning" }
        if hour < 17 { return "Good afternoon" }
        return "Good evening"
    }

    private func addItem() {
        let text = newItemText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }

        // Check for duplicate (case-insensitive)
        let normalized = text.lowercased()
        if pantryItems.contains(where: { $0.name.lowercased() == normalized }) {
            duplicateItemName = text
            HapticManager.warning()
            return
        }

        let category = categorize(text)
        let item = PantryItem(name: text, category: category)
        modelContext.insert(item)
        newItemText = ""
        HapticManager.light()
    }

    private func forceAddItem() {
        let text = newItemText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        let category = categorize(text)
        let item = PantryItem(name: text, category: category)
        modelContext.insert(item)
        newItemText = ""
        HapticManager.light()
    }

    private func categorize(_ name: String) -> PantryCategory {
        let lower = name.lowercased()

        let proteinWords = ["chicken", "beef", "pork", "steak", "salmon", "tuna", "shrimp", "turkey", "fish", "lamb", "bacon", "sausage", "tofu", "tempeh", "egg"]
        if proteinWords.contains(where: { lower.contains($0) }) { return .protein }

        let produceWords = ["apple", "banana", "orange", "berry", "grape", "lemon", "lime", "avocado", "tomato", "onion", "garlic", "pepper", "lettuce", "spinach", "kale", "broccoli", "carrot", "celery", "cucumber", "potato", "mushroom", "corn", "mango", "pineapple", "watermelon", "strawberry", "blueberry"]
        if produceWords.contains(where: { lower.contains($0) }) { return .produce }

        let dairyWords = ["milk", "cheese", "yogurt", "butter", "cream", "cottage", "mozzarella", "cheddar", "parmesan"]
        if dairyWords.contains(where: { lower.contains($0) }) { return .dairy }

        let grainWords = ["bread", "rice", "pasta", "oat", "cereal", "quinoa", "tortilla", "wrap", "bagel", "noodle", "flour"]
        if grainWords.contains(where: { lower.contains($0) }) { return .grains }

        let frozenWords = ["frozen", "ice cream", "popsicle", "pizza"]
        if frozenWords.contains(where: { lower.contains($0) }) { return .frozen }

        let beverageWords = ["water", "juice", "soda", "coffee", "tea", "kombucha", "wine", "beer"]
        if beverageWords.contains(where: { lower.contains($0) }) { return .beverages }

        let snackWords = ["chips", "crackers", "nuts", "popcorn", "granola", "bar", "cookie", "chocolate"]
        if snackWords.contains(where: { lower.contains($0) }) { return .snacks }

        let condimentWords = ["sauce", "ketchup", "mustard", "mayo", "dressing", "oil", "vinegar", "soy", "salt", "pepper", "spice", "seasoning", "honey", "syrup"]
        if condimentWords.contains(where: { lower.contains($0) }) { return .condiments }

        return .other
    }

    private func categoryColor(_ category: PantryCategory) -> Color {
        switch category {
        case .protein: Color(hex: 0xF87171)      // coral red
        case .produce: Color(hex: 0x4ADE80)      // bright green
        case .dairy: Color(hex: 0x38BDF8)        // sky blue
        case .grains: Color(hex: 0xFBBF24)       // gold amber
        case .frozen: Color(hex: 0x67E8F9)       // ice cyan
        case .pantryStaple: Color(hex: 0xA78BFA) // violet
        case .snacks: Color(hex: 0xFB923C)       // orange
        case .beverages: Color(hex: 0x60A5FA)    // indigo blue
        case .condiments: Color(hex: 0xF472B6)   // pink
        case .other: Color(hex: 0x9CA3AF)        // gray
        }
    }
}
