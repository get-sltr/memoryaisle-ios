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
    @FocusState private var inputFocused: Bool

    init() {
        _categories = State(initialValue: Self.defaultList())
    }

    private var checkedCount: Int {
        categories.flatMap(\.items).filter(\.isChecked).count
    }

    private var totalCount: Int {
        categories.flatMap(\.items).count
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.violet.opacity(0.6))
                }

                Spacer()

                Text("Grocery List")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Theme.Text.primary)

                Spacer()

                Text("\(checkedCount)/\(totalCount)")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color(hex: 0xA78BFA).opacity(0.6))
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            // List
            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    ForEach(Array(categories.enumerated()), id: \.element.id) { catIndex, category in
                        categorySection(catIndex: catIndex, category: category)
                    }

                    // Done button when all checked
                    if checkedCount > 0 {
                        Button {
                            HapticManager.heavy()
                            // Remove all checked items by rebuilding categories
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
                                    .fill(Color(hex: 0x34D399).opacity(0.2))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color(hex: 0x34D399).opacity(0.3), lineWidth: 0.5)
                            )
                            .shadow(color: Color(hex: 0x34D399).opacity(0.15), radius: 12, y: 4)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                    }

                    Spacer(minLength: 80)
                }
                .padding(.top, 8)
            }

            // Bottom input bar
            inputBar
        }
        .themeBackground()
        .overlay {
            if showConfetti {
                confettiOverlay
            }
        }
        .alert("\(duplicateName) is already on the list", isPresented: $showDuplicateAlert) {
            Button("OK") {}
        }
    }

    // MARK: - Category Section

    private func categorySection(catIndex: Int, category: GroceryCategory) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Category header
            HStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(.system(size: 11))
                    .foregroundStyle(Color(hex: category.color))
                Text(category.name.uppercased())
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color(hex: category.color).opacity(0.7))
                    .tracking(1)

                Rectangle()
                    .fill(Color(hex: category.color).opacity(0.1))
                    .frame(height: 0.5)

                Text("\(category.items.filter { !$0.isChecked }.count)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color(hex: category.color).opacity(0.4))
            }
            .padding(.horizontal, 20)

            // Items
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

    @State private var voiceManager =
    VoiceManager()

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 10) {
            // Mic button
            Button {
                HapticManager.medium()
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
            } label: {
                Image(systemName: micActive ? "waveform" : "mic.fill")
                    .font(.system(size: 17))
                    .foregroundStyle(
                        micActive
                            ? Color(hex: 0xA78BFA)
                            : Theme.Text.secondary(for: scheme)
                    )
                    
                    .background(
                        Circle().fill(
                            micActive
                                ? Color(hex: 0xA78BFA).opacity(0.15)
                                : Theme.Surface.glass(for: scheme)
                        )
                    )
            }

            // Text field
            TextField("Add item...", text: $inputText)
                .font(.system(size: 16))
                .foregroundStyle(Theme.Text.primary)
                .focused($inputFocused)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Theme.Surface.glass(for: scheme))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Theme.Border.glass(for: scheme), lineWidth: Theme.glassBorderWidth)
                )
                .onSubmit {
                    addItem(inputText)
                    inputText = ""
                }

            // Add button
            Button {
                guard !inputText.isEmpty else { return }
                HapticManager.light()
                addItem(inputText)
                inputText = ""
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(
                        inputText.isEmpty
                            ? Theme.Text.tertiary(for: scheme)
                            : Color(hex: 0xA78BFA)
                    )
            }
            .disabled(inputText.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Theme.Surface.glass(for: scheme))
                .frame(height: 0.5)
        }
    }

    // MARK: - Confetti

    private var confettiOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    showConfetti = false
                    dismiss()
                }

            VStack(spacing: 20) {
                // Confetti particles
                ZStack {
                    ForEach(0..<30, id: \.self) { i in
                        ConfettiPiece(index: i)
                    }
                }
                .frame(height: 200)

                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color(hex: 0x34D399))

                Text("Shopping done!")
                    .font(.system(size: 28, weight: .light, design: .serif))
                    .foregroundStyle(.white)
                    .tracking(0.3)

                Text("Everything's checked off.\nTime to cook something amazing.")
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.45))
                    .multilineTextAlignment(.center)

                GlowButton("Back to home") {
                    showConfetti = false
                    dismiss()
                }
                .padding(.horizontal, 50)
                .padding(.top, 8)
            }
        }
        .transition(.opacity)
    }

    // MARK: - Add Item

    @State private var showDuplicateAlert = false
    @State private var duplicateName = ""

    private func addItem(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        // Check for duplicates across all categories
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

// MARK: - Confetti Piece

struct ConfettiPiece: View {
    let index: Int
    @State private var animate = false

    private let colors: [UInt] = [0xA78BFA, 0x34D399, 0xFBBF24, 0x38BDF8, 0xF87171, 0xFCA5A5, 0x67E8F9, 0xFDE68A]

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(Color(hex: colors[index % colors.count]))
            .frame(width: CGFloat.random(in: 4...8), height: CGFloat.random(in: 8...16))
            .rotationEffect(.degrees(animate ? Double.random(in: 0...360) : 0))
            .offset(
                x: animate ? CGFloat.random(in: -160...160) : 0,
                y: animate ? CGFloat.random(in: -80...200) : -50
            )
            .opacity(animate ? 0 : 1)
            .onAppear {
                withAnimation(
                    .easeOut(duration: Double.random(in: 1.2...2.5))
                    .delay(Double.random(in: 0...0.3))
                ) {
                    animate = true
                }
            }
    }
}

extension GroceryListView {
    // MARK: - Default Grocery List

    private static func defaultList() -> [GroceryCategory] {
        [
            GroceryCategory(name: "Protein", icon: "flame.fill", color: 0xA78BFA, items: [
                GroceryItem(name: "Chicken breast", quantity: "2 lbs", proteinPer: "31g/4oz"),
                GroceryItem(name: "Salmon fillets", quantity: "1 lb", proteinPer: "23g/4oz"),
                GroceryItem(name: "Eggs (dozen)", quantity: "1", proteinPer: "6g each"),
                GroceryItem(name: "Greek yogurt", quantity: "32 oz", proteinPer: "15g/cup"),
                GroceryItem(name: "Whey protein", quantity: "1 tub", proteinPer: "25g/scoop"),
            ]),
            GroceryCategory(name: "Dairy", icon: "cup.and.saucer.fill", color: 0x38BDF8, items: [
                GroceryItem(name: "Cottage cheese", quantity: "16 oz", proteinPer: "14g/cup"),
                GroceryItem(name: "Almond milk", quantity: "1/2 gal", proteinPer: nil),
                GroceryItem(name: "Parmesan", quantity: "4 oz", proteinPer: nil),
            ]),
            GroceryCategory(name: "Produce", icon: "carrot.fill", color: 0x34D399, items: [
                GroceryItem(name: "Broccoli", quantity: "2 heads", proteinPer: nil),
                GroceryItem(name: "Spinach", quantity: "1 bag", proteinPer: nil),
                GroceryItem(name: "Bananas", quantity: "6", proteinPer: nil),
                GroceryItem(name: "Berries (mixed)", quantity: "1 pint", proteinPer: nil),
                GroceryItem(name: "Avocados", quantity: "3", proteinPer: nil),
                GroceryItem(name: "Sweet potatoes", quantity: "3", proteinPer: nil),
            ]),
            GroceryCategory(name: "Grains", icon: "leaf.fill", color: 0xFBBF24, items: [
                GroceryItem(name: "Brown rice", quantity: "2 lbs", proteinPer: nil),
                GroceryItem(name: "Quinoa", quantity: "1 lb", proteinPer: "8g/cup"),
                GroceryItem(name: "Oats", quantity: "18 oz", proteinPer: "5g/cup"),
            ]),
            GroceryCategory(name: "Pantry", icon: "bag.fill", color: 0xFCA5A5, items: [
                GroceryItem(name: "Hemp seeds", quantity: "8 oz", proteinPer: "10g/3tbsp"),
                GroceryItem(name: "Almond butter", quantity: "1 jar", proteinPer: "7g/2tbsp"),
                GroceryItem(name: "Chia seeds", quantity: "6 oz", proteinPer: "5g/2tbsp"),
                GroceryItem(name: "Ginger tea", quantity: "1 box", proteinPer: nil),
            ]),
            GroceryCategory(name: "Frozen", icon: "snowflake", color: 0x67E8F9, items: [
                GroceryItem(name: "Frozen berries", quantity: "1 bag", proteinPer: nil),
                GroceryItem(name: "Frozen broccoli", quantity: "1 bag", proteinPer: nil),
                GroceryItem(name: "Frozen chicken", quantity: "2 lbs", proteinPer: "31g/4oz"),
            ]),
        ]
    }
}

// MARK: - Grocery Item Row (extracted for compiler performance)

struct GroceryItemRow: View {
    @Environment(\.colorScheme) private var scheme
    let item: GroceryItem
    let categoryColor: UInt
    let onToggle: () -> Void
    let onDelete: () -> Void

    private var catColor: Color { Color(hex: categoryColor) }

    var body: some View {
        Button(action: onToggle) {
            rowContent
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("Remove", systemImage: "trash")
            }
        }
    }

    private var rowContent: some View {
        HStack(spacing: 12) {
            checkIcon
            nameLabel
            Spacer()
            if !item.isChecked { detailLabels }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(rowBackground)
        .overlay(rowBorder)
        .padding(.horizontal, 16)
    }

    private var checkIcon: some View {
        Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 18))
            .foregroundStyle(item.isChecked ? Color(hex: 0x34D399) : catColor.opacity(0.4))
    }

    private var nameLabel: some View {
        Text(item.name)
            .font(.system(size: 15, weight: item.isChecked ? .regular : .medium))
            .foregroundStyle(item.isChecked ? Theme.Text.tertiary(for: scheme) : Theme.Text.primary)
            .strikethrough(item.isChecked, color: Theme.Text.tertiary(for: scheme))
    }

    private var detailLabels: some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(item.quantity)
                .font(.system(size: 11))
                .foregroundStyle(Theme.Text.tertiary(for: scheme))
            if let protein = item.proteinPer {
                Text(protein)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(catColor.opacity(0.5))
            }
        }
    }

    @ViewBuilder
    private var rowBackground: some View {
        if item.isChecked {
            Color.clear
        } else {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [catColor.opacity(0.06), catColor.opacity(0.02)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
    }

    @ViewBuilder
    private var rowBorder: some View {
        if !item.isChecked {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(catColor.opacity(0.08), lineWidth: 0.5)
        }
    }
}
