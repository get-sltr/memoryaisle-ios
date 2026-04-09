import SwiftUI

struct FoodSearchView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [FoodSearchResult] = []
    @State private var isSearching = false
    private let client = NutritionAPIClient()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.violet.opacity(0.6))
                }

                Spacer()

                Text("Search Foods")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Theme.Text.primary)

                Spacer()

                Color.clear
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            // Search bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.Text.tertiary(for: scheme))

                TextField("Search foods...", text: $query)
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.Text.primary)
                    .onSubmit { performSearch() }

                if isSearching {
                    ProgressView()
                        .tint(Color.violet)
                        .scaleEffect(0.8)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Theme.Surface.glass(for: scheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Theme.Border.glass(for: scheme), lineWidth: Theme.glassBorderWidth)
            )
            .padding(.horizontal, 20)
            .padding(.top, 16)

            // Results
            ScrollView(showsIndicators: false) {
                if results.isEmpty && !query.isEmpty && !isSearching {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 28))
                            .foregroundStyle(Theme.Text.tertiary(for: scheme))

                        Text("No results found")
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.Text.tertiary(for: scheme))
                    }
                    .padding(.top, 60)
                } else {
                    VStack(spacing: 6) {
                        ForEach(results) { food in
                            foodRow(food)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                }
            }
        }
        .themeBackground()
    }

    private func foodRow(_ food: FoodSearchResult) -> some View {
        Button {
            HapticManager.light()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(food.name)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.Text.primary)
                        .lineLimit(1)

                    if !food.brand.isEmpty {
                        Text(food.brand)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.Text.tertiary(for: scheme))
                            .lineLimit(1)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(food.protein))g")
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.violet)

                    Text("\(food.calories) cal")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Theme.Text.tertiary(for: scheme))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Theme.Surface.glass(for: scheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Theme.Border.glass(for: scheme), lineWidth: Theme.glassBorderWidth)
            )
        }
        .buttonStyle(.plain)
    }

    private func performSearch() {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isSearching = true

        Task {
            do {
                results = try await client.search(query: query)
            } catch {
                results = []
            }
            isSearching = false
        }
    }
}
