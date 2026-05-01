import SwiftData
import SwiftUI

/// The destination of the menu's "Favorites" row. Lists every `SavedRecipe`
/// the user has saved, split into two sections by `kind`:
///
///   I · MIRA SUGGESTIONS — meals favorited from the Today dashboard's
///       recommendation carousel (heart button). Stored as
///       `SavedRecipe(kind: .suggestion)` with macro snapshot fields.
///   II · SAVED RECIPES — full recipes saved from a Mira chat via
///       SaveRecipeSheet (`kind: .recipe`).
///
/// Both kinds live in one SwiftData model (Option A) — see SavedRecipe.
struct FavoritesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedRecipe.savedAt, order: .reverse) private var saved: [SavedRecipe]

    @State private var selectedRecipe: SavedRecipe?

    private var suggestions: [SavedRecipe] {
        saved.filter { $0.kind == .suggestion }
    }

    private var recipes: [SavedRecipe] {
        saved.filter { $0.kind == .recipe }
    }

    var body: some View {
        ZStack {
            EditorialBackground(mode: .night)

            ScrollView {
                VStack(spacing: 0) {
                    header
                    HairlineDivider().padding(.vertical, 8)

                    if saved.isEmpty {
                        emptyState
                    } else {
                        if !suggestions.isEmpty {
                            section(label: "I · MIRA SUGGESTIONS") {
                                ForEach(Array(suggestions.enumerated()), id: \.element.id) { idx, entry in
                                    suggestionRow(entry)
                                    if idx < suggestions.count - 1 { rowDivider }
                                }
                            }
                        }
                        if !suggestions.isEmpty && !recipes.isEmpty {
                            sectionDivider
                        }
                        if !recipes.isEmpty {
                            section(label: "II · SAVED RECIPES") {
                                ForEach(Array(recipes.enumerated()), id: \.element.id) { idx, entry in
                                    recipeRow(entry)
                                    if idx < recipes.count - 1 { rowDivider }
                                }
                            }
                        }
                    }

                    footer
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)

            VStack {
                HStack {
                    Spacer()
                    doneButton
                }
                .padding(.top, 16)
                .padding(.trailing, 24)
                Spacer()
            }
        }
        .preferredColorScheme(.light)
        .ignoresSafeArea()
        .sheet(item: $selectedRecipe) { entry in
            // Detail view only exists for the recipe kind today; suggestion
            // entries fall back to the same sheet but render their macro
            // snapshot inside `bodyText`.
            SavedRecipeDetailView(recipe: entry)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 56)
            Image(systemName: "heart.fill")
                .font(.system(size: 22))
                .foregroundStyle(Theme.Editorial.onSurface)
                .padding(.bottom, 14)
            Text("Favorites")
                .font(.system(size: 26, weight: .regular, design: .serif))
                .tracking(0.6)
                .foregroundStyle(Theme.Editorial.onSurface)
            Text("SAVED MEALS · RECIPES")
                .font(Theme.Editorial.Typography.caps(9, weight: .medium))
                .tracking(2.8)
                .foregroundStyle(Theme.Editorial.onSurfaceMuted)
                .padding(.top, 8)
                .padding(.bottom, 28)
        }
    }

    private var doneButton: some View {
        Button {
            HapticManager.light()
            dismiss()
        } label: {
            Text("DONE")
                .font(Theme.Editorial.Typography.capsBold(11))
                .tracking(2.0)
                .foregroundStyle(Theme.Editorial.onSurface.opacity(0.85))
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Done")
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 24)
            Image(systemName: "heart")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(Theme.Editorial.onSurface.opacity(0.5))
            Text("Nothing saved yet.")
                .font(.system(size: 16, design: .serif))
                .foregroundStyle(Theme.Editorial.onSurface.opacity(0.7))
                .italic()
            Text("TAP THE HEART ON A MIRA SUGGESTION TO SAVE IT HERE")
                .font(Theme.Editorial.Typography.caps(9, weight: .medium))
                .tracking(1.8)
                .foregroundStyle(Theme.Editorial.onSurface.opacity(0.45))
                .multilineTextAlignment(.center)
                .padding(.top, 4)
            Spacer().frame(height: 24)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Section + row primitives

    @ViewBuilder
    private func section<Content: View>(
        label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(Theme.Editorial.Typography.caps(9, weight: .medium))
                .tracking(2.8)
                .foregroundStyle(Theme.Editorial.onSurfaceMuted)
                .padding(.vertical, 14)
                .padding(.horizontal, 4)
            content()
        }
    }

    private var sectionDivider: some View {
        HairlineDivider().padding(.vertical, 8)
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(Theme.Editorial.onSurface.opacity(0.08))
            .frame(height: 0.5)
            .padding(.horizontal, 4)
    }

    // MARK: - Suggestion row

    @ViewBuilder
    private func suggestionRow(_ entry: SavedRecipe) -> some View {
        Button {
            HapticManager.light()
            selectedRecipe = entry
        } label: {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.title)
                        .font(.system(size: 16, design: .serif))
                        .italic()
                        .foregroundStyle(Theme.Editorial.onSurface)
                    Text(macroLine(for: entry))
                        .font(Theme.Editorial.Typography.caps(9, weight: .medium))
                        .tracking(1.6)
                        .foregroundStyle(Theme.Editorial.onSurface.opacity(0.5))
                }

                Spacer()

                unsaveButton(entry)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func macroLine(for entry: SavedRecipe) -> String {
        var parts: [String] = []
        if let cal = entry.savedCalories { parts.append("\(cal) CAL") }
        if let p = entry.savedProteinG { parts.append("\(p)G PROTEIN") }
        if let f = entry.savedFatG { parts.append("\(f)G FAT") }
        return parts.isEmpty ? entry.categoryRaw.uppercased() : parts.joined(separator: " · ")
    }

    // MARK: - Recipe row

    @ViewBuilder
    private func recipeRow(_ entry: SavedRecipe) -> some View {
        Button {
            HapticManager.light()
            selectedRecipe = entry
        } label: {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.title)
                        .font(.system(size: 16, design: .serif))
                        .foregroundStyle(Theme.Editorial.onSurface)
                    Text(entry.categoryRaw.uppercased())
                        .font(Theme.Editorial.Typography.caps(9, weight: .medium))
                        .tracking(1.6)
                        .foregroundStyle(Theme.Editorial.onSurface.opacity(0.5))
                }

                Spacer()

                unsaveButton(entry)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func unsaveButton(_ entry: SavedRecipe) -> some View {
        Button {
            HapticManager.light()
            modelContext.delete(entry)
        } label: {
            Image(systemName: "heart.fill")
                .font(.system(size: 14))
                .foregroundStyle(Theme.Editorial.onSurface.opacity(0.85))
                .padding(8)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Remove from favorites")
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkle")
                .font(.system(size: 10))
                .foregroundStyle(Theme.Editorial.onSurface.opacity(0.5))
            Text("v 2.0.0")
                .font(Theme.Editorial.Typography.caps(9, weight: .regular))
                .tracking(2.8)
                .foregroundStyle(Theme.Editorial.onSurface.opacity(0.4))
        }
        .padding(.top, 32)
        .padding(.bottom, 8)
    }
}
