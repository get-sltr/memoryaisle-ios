import SwiftData
import SwiftUI

/// Form sheet presented when the user taps "Save to Recipes" under a
/// Mira-generated recipe. Lets them edit the auto-extracted title, pick a
/// category, and review the body before persisting a `SavedRecipe`.
struct SaveRecipeSheet: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let bodyText: String

    @State private var title: String = ""
    @State private var category: RecipeCategory = .dinner
    @FocusState private var titleFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    titleField
                    categoryPicker
                    preview
                }
                .padding(20)
            }

            saveButton
        }
        .section(.recipes)
        .themeBackground()
        .onAppear {
            if title.isEmpty {
                title = bodyText.extractedRecipeTitle
            }
            titleFocused = true
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button("Cancel") { dismiss() }
                .font(Typography.bodyMedium)
                .foregroundStyle(Theme.Text.secondary(for: scheme))
            Spacer()
            Text("Save Recipe")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.Text.primary)
            Spacer()
            Color.clear.frame(width: 56)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }

    // MARK: - Title

    private var titleField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("TITLE")
                .font(Typography.label)
                .foregroundStyle(Theme.Text.tertiary(for: scheme))
                .tracking(1.2)
            TextField("Recipe title", text: $title)
                .font(Typography.bodyLarge)
                .foregroundStyle(Theme.Text.primary)
                .focused($titleFocused)
                .padding(12)
                .background(Theme.Surface.glass(for: scheme))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Theme.Border.glass(for: scheme), lineWidth: Theme.glassBorderWidth)
                )
        }
    }

    // MARK: - Category

    private var categoryPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("CATEGORY")
                .font(Typography.label)
                .foregroundStyle(Theme.Text.tertiary(for: scheme))
                .tracking(1.2)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(RecipeCategory.allCases, id: \.self) { cat in
                        categoryChip(cat)
                    }
                }
            }
        }
    }

    private func categoryChip(_ cat: RecipeCategory) -> some View {
        let isSelected = category == cat
        return Button {
            HapticManager.selection()
            category = cat
        } label: {
            HStack(spacing: 6) {
                Image(systemName: cat.icon)
                    .font(.system(size: 11))
                Text(cat.rawValue)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
            }
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

    // MARK: - Preview

    private var preview: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("PREVIEW")
                .font(Typography.label)
                .foregroundStyle(Theme.Text.tertiary(for: scheme))
                .tracking(1.2)
            Text(bodyText)
                .font(Typography.bodySmall)
                .foregroundStyle(Theme.Text.secondary(for: scheme))
                .lineSpacing(3)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.Surface.glass(for: scheme))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Theme.Border.glass(for: scheme), lineWidth: Theme.glassBorderWidth)
                )
        }
    }

    // MARK: - Save

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var saveButton: some View {
        Button {
            save()
        } label: {
            Text("Save to Recipes")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    Capsule().fill(SectionPalette.primary(.recipes, for: scheme))
                )
        }
        .buttonStyle(.plain)
        .disabled(!canSave)
        .opacity(canSave ? 1.0 : 0.5)
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let recipe = SavedRecipe(
            title: trimmed,
            bodyText: bodyText,
            categoryRaw: category.rawValue
        )
        modelContext.insert(recipe)
        try? modelContext.save()
        HapticManager.success()
        dismiss()
    }
}
