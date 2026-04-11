import SwiftData
import SwiftUI

struct GroceryCategory: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let color: UInt
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
    @State private var categories: [GroceryCategory]
    @State private var inputText = ""
    @State private var micActive = false
    @State private var showConfetti = false
    @State private var showDuplicateAlert = false
    @State private var duplicateName = ""
    @State private var voiceManager = VoiceManager()
    @FocusState private var inputFocused: Bool

    init() {
        _categories = State(initialValue: GroceryListSeed.defaultList())
    }

    private var checkedCount: Int {
        categories.flatMap(\.items).filter(\.isChecked).count
    }

    private var totalCount: Int {
        categories.flatMap(\.items).count
    }

    private var heroSubtitle: String {
        "\(checkedCount) of \(totalCount) items checked"
    }

    var body: some View {
        VStack(spacing: 0) {
            HeroHeader(title: "Grocery", subtitle: heroSubtitle) {
                CloseButton(action: { dismiss() })
            }

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 14) {
                    ForEach(Array(categories.enumerated()), id: \.element.id) { catIndex, category in
                        categorySection(catIndex: catIndex, category: category)
                    }

                    if checkedCount > 0 {
                        doneShoppingButton
                    }

                    Spacer(minLength: 80)
                }
                .padding(.top, 18)
            }

            inputBar
        }
        .section(.grocery)
        .themeBackground()
        .overlay {
            if showConfetti {
                GroceryConfettiOverlay {
                    showConfetti = false
                    dismiss()
                }
            }
        }
        .alert("\(duplicateName) is already on the list", isPresented: $showDuplicateAlert) {
            Button("OK") {}
        }
    }

    // MARK: - Category Section

    private func categorySection(catIndex: Int, category: GroceryCategory) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(Color(hex: category.color))
                    .frame(width: 2, height: 14)
                Image(systemName: category.icon)
                    .font(.system(size: 11))
                    .foregroundStyle(Color(hex: category.color))
                Text(category.name.uppercased())
                    .font(Typography.label)
                    .foregroundStyle(Color(hex: category.color).opacity(0.85))
                    .tracking(1.2)

                Spacer()

                Text("\(category.items.filter { !$0.isChecked }.count)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color(hex: category.color).opacity(0.5))
            }
            .padding(.horizontal, 20)

            ForEach(Array(category.items.enumerated()), id: \.element.id) { itemIndex, item in
                GroceryItemRow(
                    item: item,
                    categoryColor: category.color,
                    onToggle: {
                        HapticManager.selection()
                        withAnimation(.easeOut(duration: 0.15)) {
                            categories[catIndex].items[itemIndex].isChecked.toggle()
                        }
                    },
                    onDelete: {
                        _ = withAnimation {
                            categories[catIndex].items.remove(at: itemIndex)
                        }
                        HapticManager.light()
                    }
                )
            }
        }
    }

    // MARK: - Done shopping

    private var doneShoppingButton: some View {
        Button {
            HapticManager.heavy()
            var updated = categories
            for i in updated.indices {
                updated[i].items = updated[i].items.filter { !$0.isChecked }
            }
            categories = updated
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                showConfetti = true
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: checkedCount == totalCount ? "checkmark.seal.fill" : "cart.badge.minus")
                    .font(.system(size: 16))
                Text(checkedCount == totalCount ? "Shopping complete!" : "Done shopping")
                    .font(.system(size: 15, weight: .medium))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Theme.Semantic.onTrack(for: scheme).opacity(0.25))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Theme.Semantic.onTrack(for: scheme).opacity(0.40), lineWidth: 0.5)
            )
            .shadow(color: Theme.Semantic.onTrack(for: scheme).opacity(0.22), radius: 14, y: 4)
        }
        .accessibilityLabel("Done shopping")
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 10) {
            micButton
            textField
            addButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Theme.Section.border(.grocery, for: scheme))
                .frame(height: 0.5)
        }
    }

    private var micButton: some View {
        Button {
            HapticManager.medium()
            toggleVoice()
        } label: {
            Image(systemName: micActive ? "waveform" : "mic.fill")
                .font(.system(size: 17))
                .foregroundStyle(
                    micActive
                        ? SectionPalette.primary(.grocery, for: scheme)
                        : Theme.Text.secondary(for: scheme)
                )
                .frame(width: 40, height: 40)
                .background(
                    Circle().fill(
                        micActive
                            ? Theme.Section.glass(.grocery, for: scheme)
                            : Theme.Surface.glass(for: scheme)
                    )
                )
        }
        .accessibilityLabel(micActive ? "Stop listening" : "Voice input")
    }

    private var textField: some View {
        TextField("Add item…", text: $inputText)
            .font(.system(size: 16))
            .foregroundStyle(Theme.Text.primary)
            .focused($inputFocused)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Theme.Section.glass(.grocery, for: scheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Theme.Section.border(.grocery, for: scheme), lineWidth: Theme.glassBorderWidth)
            )
            .onSubmit {
                addItem(inputText)
                inputText = ""
            }
    }

    private var addButton: some View {
        Button {
            guard !inputText.isEmpty else { return }
            HapticManager.light()
            addItem(inputText)
            inputText = ""
        } label: {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 30))
                .foregroundStyle(
                    inputText.isEmpty
                        ? Theme.Text.tertiary(for: scheme)
                        : SectionPalette.primary(.grocery, for: scheme)
                )
        }
        .accessibilityLabel("Add item")
        .disabled(inputText.isEmpty)
    }

    private func toggleVoice() {
        if voiceManager.isListening {
            voiceManager.stopListening()
            withAnimation { micActive = false }
            if !voiceManager.transcribedText.isEmpty {
                addItem(voiceManager.transcribedText)
                voiceManager.transcribedText = ""
            }
        } else {
            Task {
                let granted = await voiceManager.requestPermissions()
                if granted {
                    withAnimation { micActive = true }
                    voiceManager.startListening()
                }
            }
        }
    }

    // MARK: - Add Item

    private func addItem(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let allItems = categories.flatMap(\.items)
        if allItems.contains(where: { $0.name.lowercased() == trimmed.lowercased() }) {
            duplicateName = trimmed
            showDuplicateAlert = true
            HapticManager.warning()
            return
        }

        let item = GroceryItem(name: trimmed, quantity: "", proteinPer: nil)
        if categories.indices.contains(0) {
            categories[0].items.insert(item, at: 0)
        }
        HapticManager.success()
    }
}

