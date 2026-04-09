import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.modelContext) private var modelContext
    @State private var showProfile = false
    @State private var showCalendar = false
    @Query private var profiles: [UserProfile]
    @Query(sort: \PantryItem.addedDate, order: .reverse) private var pantryItems: [PantryItem]
    @Query(sort: \NutritionLog.date, order: .reverse) private var logs: [NutritionLog]
    @State private var newItemText = ""
    @FocusState private var inputFocused: Bool

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(greeting)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.Text.tertiary(for: scheme))
                    Text("Grocery List")
                        .font(.system(size: 28, weight: .light, design: .serif))
                        .foregroundStyle(Theme.Text.primary)
                        .tracking(0.3)
                }

                Spacer()

                Button {
                    showCalendar = true
                } label: {
                    Image(systemName: "calendar")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.violet.opacity(0.6))
                }

                Button {
                    showProfile = true
                } label: {
                    OnboardingLogo(size: 32)
                }
                .padding(.leading, 12)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 12)
            .sheet(isPresented: $showProfile) { ProfileView() }
            .sheet(isPresented: $showCalendar) { CalendarView() }

            // Item count
            if !pantryItems.isEmpty {
                HStack {
                    Text("\(pantryItems.count) items")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Theme.Text.tertiary(for: scheme))
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }

            // Grocery list
            if pantryItems.isEmpty {
                emptyState
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        ForEach(pantryItems) { item in
                            groceryRow(item)
                        }
                    }
                    .padding(.bottom, 80)
                }
            }

            Spacer()

            // Input bar
            inputBar
        }
        .themeBackground()
        .navigationBarHidden(true)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "cart")
                .font(.system(size: 48))
                .foregroundStyle(Color.violet.opacity(0.2))

            Text("Your list is empty")
                .font(.system(size: 18, weight: .light, design: .serif))
                .foregroundStyle(Theme.Text.secondary(for: scheme))

            Text("Add items below or ask Mira for suggestions")
                .font(.system(size: 13))
                .foregroundStyle(Theme.Text.tertiary(for: scheme))

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Grocery Row

    private func groceryRow(_ item: PantryItem) -> some View {
        HStack(spacing: 14) {
            // Category icon
            Image(systemName: item.category.icon)
                .font(.system(size: 12))
                .foregroundStyle(Color.violet.opacity(0.4))
                .frame(width: 20)

            // Item name
            Text(item.name)
                .font(.system(size: 16))
                .foregroundStyle(Theme.Text.primary)

            Spacer()

            // Check off (removes item)
            Button {
                HapticManager.success()
                withAnimation(.easeOut(duration: 0.2)) {
                    modelContext.delete(item)
                }
            } label: {
                Image(systemName: "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(Theme.Text.tertiary(for: scheme))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(Color.violet.opacity(0.6))

            TextField("Add an item...", text: $newItemText)
                .font(.system(size: 16))
                .foregroundStyle(Theme.Text.primary)
                .focused($inputFocused)
                .onSubmit { addItem() }

            if !newItemText.isEmpty {
                Button {
                    addItem()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Color.violet)
                }
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
        let item = PantryItem(name: text)
        modelContext.insert(item)
        newItemText = ""
        HapticManager.light()
    }
}
