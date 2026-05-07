import SwiftData
import SwiftUI
import UIKit

struct GroceryListScreen: View {
    var mode: MAMode = .auto
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [UserProfile]
    @Query(
        filter: #Predicate<PantryItem> { $0.isInPantry == false },
        sort: \PantryItem.addedDate,
        order: .reverse
    ) private var pantryItems: [PantryItem]
    @State private var newItemText = ""
    @State private var duplicateItemName: String?
    @State private var copiedConfirmation: Bool = false
    @FocusState private var inputFocused: Bool

    private var profile: UserProfile? { profiles.first }

    private var groupedItems: [(category: PantryCategory, items: [PantryItem])] {
        let grouped = Dictionary(grouping: pantryItems, by: \.category)
        let order: [PantryCategory] = [.protein, .produce, .dairy, .grains, .frozen, .pantryStaple, .snacks, .beverages, .condiments, .other]
        return order.compactMap { cat in
            guard let items = grouped[cat], !items.isEmpty else { return nil }
            return (category: cat, items: items)
        }
    }

    private var heroTrailing: String {
        let count = pantryItems.count
        if count == 0 { return "EMPTY" }
        return "\(count) \(count == 1 ? "ITEM" : "ITEMS")"
    }

    var body: some View {
        ZStack {
            EditorialBackground(mode: mode)

            VStack(alignment: .leading, spacing: 0) {
                topBar
                Masthead(wordmark: "GROCERY", trailing: heroTrailing)
                    .padding(.bottom, 22)

                if pantryItems.isEmpty {
                    emptyState
                } else {
                    listScroll
                }

                Spacer(minLength: 0)
                inputBar
            }
            .padding(.horizontal, Theme.Editorial.Spacing.pad)
            .padding(.top, 12)
        }
        .preferredColorScheme(.light)
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

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 8) {
            if !pantryItems.isEmpty {
                topBarButton(
                    systemName: copiedConfirmation ? "checkmark" : "doc.on.doc",
                    accessibility: copiedConfirmation ? "Copied" : "Copy list"
                ) {
                    copyListToClipboard()
                }
                topBarButton(
                    systemName: "square.and.arrow.up",
                    accessibility: "Share list"
                ) {
                    shareList()
                }
            }
            Spacer()
            topBarButton(systemName: "xmark", accessibility: "Close grocery list") {
                dismiss()
            }
        }
        .padding(.bottom, 14)
    }

    private func topBarButton(
        systemName: String,
        accessibility: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.Editorial.onSurface)
                .frame(width: 36, height: 36)
                .overlay(Circle().stroke(Theme.Editorial.hairline, lineWidth: 0.5))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibility)
    }

    // MARK: - Share / copy

    private func shareList() {
        HapticManager.light()
        let text = GroceryAdder.sharePlainText(items: pantryItems)
        guard !text.isEmpty else { return }
        ShareSheetPresenter.present(items: [text])
    }

    private func copyListToClipboard() {
        let text = GroceryAdder.sharePlainText(items: pantryItems)
        guard !text.isEmpty else { return }
        UIPasteboard.general.string = text
        HapticManager.success()
        withAnimation(.easeInOut(duration: 0.2)) {
            copiedConfirmation = true
        }
        // Reset the icon after a brief moment so the next tap isn't
        // ambiguous about whether it copied again.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.easeInOut(duration: 0.2)) {
                copiedConfirmation = false
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "cart")
                .font(.system(size: 40))
                .foregroundStyle(Theme.Editorial.onSurfaceFaint)
            Text("YOUR LIST IS EMPTY")
                .font(Theme.Editorial.Typography.capsBold(11))
                .tracking(3)
                .foregroundStyle(Theme.Editorial.onSurface)
            Text("Type below or tap the mic to add items")
                .font(Theme.Editorial.Typography.body())
                .foregroundStyle(Theme.Editorial.onSurfaceMuted)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - List

    private var listScroll: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 26) {
                ForEach(groupedItems, id: \.category) { group in
                    categorySection(group.category, items: group.items)
                }
                Spacer(minLength: 60)
            }
            .padding(.bottom, 16)
        }
    }

    private func categorySection(_ category: PantryCategory, items: [PantryItem]) -> some View {
        let accent = GroceryCategoryHelpers.color(for: category)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle()
                    .fill(accent)
                    .frame(width: 6, height: 6)
                Image(systemName: category.icon)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.Editorial.onSurface)
                Text(category.rawValue.uppercased())
                    .font(Theme.Editorial.Typography.capsBold(10))
                    .tracking(2.8)
                    .foregroundStyle(Theme.Editorial.onSurface)
                Spacer()
                Text("\(items.count)")
                    .font(Theme.Editorial.Typography.dataValue())
                    .tracking(1.2)
                    .foregroundStyle(Theme.Editorial.onSurfaceFaint)
            }
            HairlineDivider().opacity(0.5)
            VStack(spacing: 0) {
                ForEach(items) { item in
                    itemRow(item, accent: accent)
                    HairlineDivider().opacity(0.3)
                }
            }
        }
    }

    private func itemRow(_ item: PantryItem, accent: Color) -> some View {
        Button {
            HapticManager.success()
            withAnimation(.easeOut(duration: 0.25)) {
                item.isInPantry = true
            }
        } label: {
            HStack(spacing: 14) {
                Circle()
                    .stroke(Theme.Editorial.onSurface.opacity(0.5), lineWidth: 1)
                    .frame(width: 20, height: 20)

                Text(item.name)
                    .font(Theme.Editorial.Typography.body())
                    .foregroundStyle(Theme.Editorial.onSurface)

                Spacer()
            }
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Mark \(item.name) as bought, moves to pantry")
    }

    // MARK: - Input bar

    private var inputBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "plus")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.Editorial.onSurfaceMuted)

            TextField("Add an item", text: $newItemText)
                .font(Theme.Editorial.Typography.body())
                .foregroundStyle(Theme.Editorial.onSurface)
                .focused($inputFocused)
                .onSubmit { addItem() }

            if !newItemText.isEmpty {
                Button { addItem() } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Theme.Editorial.onSurface)
                }
                .accessibilityLabel("Add item")
            } else {
                Button { inputFocused = true } label: {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.Editorial.onSurfaceFaint)
                }
                .accessibilityLabel("Voice input")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .overlay(Capsule().stroke(Theme.Editorial.hairline, lineWidth: 0.5))
        .clipShape(Capsule())
        .padding(.bottom, 18)
    }

    // MARK: - Actions

    private func addItem() {
        let text = newItemText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }

        let normalized = text.lowercased()
        if pantryItems.contains(where: { $0.name.lowercased() == normalized }) {
            duplicateItemName = text
            HapticManager.warning()
            return
        }

        insertItem(text)
    }

    private func forceAddItem() {
        let text = newItemText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        insertItem(text)
    }

    private func insertItem(_ text: String) {
        let category = GroceryCategoryHelpers.categorize(text)
        let item = PantryItem(name: text, category: category)
        modelContext.insert(item)
        newItemText = ""
        HapticManager.light()
    }
}
