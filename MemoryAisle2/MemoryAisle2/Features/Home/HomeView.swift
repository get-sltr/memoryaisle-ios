import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.modelContext) private var modelContext
    @State private var showProfile = false
    @State private var showFullGrocery = false
    @State private var showCalendar = false
    @State private var newItemText = ""
    @Query private var profiles: [UserProfile]
    @Query(sort: \PantryItem.addedDate, order: .reverse) private var pantryItems: [PantryItem]
    @Query(sort: \NutritionLog.date, order: .reverse) private var logs: [NutritionLog]

    private var profile: UserProfile? { profiles.first }
    private var todayLog: NutritionLog? {
        logs.first { Calendar.current.isDateInToday($0.date) }
    }

    private var protein: Double { todayLog?.proteinGrams ?? 0 }
    private var proteinTarget: Double { Double(profile?.proteinTargetGrams ?? 140) }
    private var water: Double { todayLog?.waterLiters ?? 0 }
    private var waterTarget: Double { profile?.waterTargetLiters ?? 2.5 }
    private var fiber: Double { todayLog?.fiberGrams ?? 0 }
    private var fiberTarget: Double { Double(profile?.fiberTargetGrams ?? 25) }
    private var calories: Double { todayLog?.caloriesConsumed ?? 0 }
    private var calorieTarget: Double { Double(profile?.calorieTarget ?? 1800) }

    private var proteinDeficit: Int {
        max(0, Int(proteinTarget - protein))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.md) {
                header
                grocerySection
                miraSuggestion
                proteinHeroCard
                macroTiles
                quickLogButtons
                if profile?.medication != nil {
                    InjectionCycleBar()
                        .padding(.horizontal, Theme.Spacing.md)
                }
                symptomQuickLog
                Spacer(minLength: 80)
            }
        }
        .themeBackground()
        .navigationBarHidden(true)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(greeting)
                    .font(Typography.bodyMedium)
                    .foregroundStyle(Theme.Text.secondary(for: scheme))
                Text("Your Daily Plan")
                    .font(Typography.displaySmall)
                    .foregroundStyle(Theme.Text.primary)
            }
            Spacer()

            Button {
                showCalendar = true
            } label: {
                Image(systemName: "calendar")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.violet.opacity(0.6))
            }
            .sheet(isPresented: $showCalendar) {
                CalendarView()
            }

            Button {
                showProfile = true
            } label: {
                OnboardingLogo(size: 32)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.top, Theme.Spacing.sm)
        .sheet(isPresented: $showProfile) {
            ProfileView()
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        if hour < 12 { return "Good morning" }
        if hour < 17 { return "Good afternoon" }
        return "Good evening"
    }

    // MARK: - Protein Hero

    private var proteinHeroCard: some View {
        GlassCardStrong {
            VStack(spacing: Theme.Spacing.md) {
                HStack {
                    Text("Protein")
                        .font(Typography.bodyMediumBold)
                        .foregroundStyle(Theme.Semantic.protein(for: scheme))
                    Spacer()
                    if proteinDeficit > 0 {
                        PillBadge(.behind, label: "\(proteinDeficit)g behind")
                    } else {
                        PillBadge(.onTrack)
                    }
                }

                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.xs) {
                    Text("\(Int(protein))")
                        .font(Typography.monoLarge)
                        .foregroundStyle(Theme.Text.primary)
                    Text("/ \(Int(proteinTarget))g")
                        .font(Typography.monoMedium)
                        .foregroundStyle(Theme.Text.secondary(for: scheme))
                }

                ProgressBar(
                    progress: proteinTarget > 0 ? protein / proteinTarget : 0,
                    category: .protein,
                    height: 8
                )
            }
            .padding(Theme.Spacing.md)
        }
        .padding(.horizontal, Theme.Spacing.md)
    }

    // MARK: - Macro Tiles

    private var macroTiles: some View {
        HStack(spacing: Theme.Spacing.sm) {
            macroTile(
                "Water",
                value: String(format: "%.1f", water),
                unit: "L",
                target: String(format: "%.1fL", waterTarget),
                category: .water,
                progress: waterTarget > 0 ? water / waterTarget : 0
            )
            macroTile(
                "Fiber",
                value: "\(Int(fiber))",
                unit: "g",
                target: "\(Int(fiberTarget))g",
                category: .fiber,
                progress: fiberTarget > 0 ? fiber / fiberTarget : 0
            )
            macroTile(
                "Cal",
                value: "\(Int(calories))",
                unit: "",
                target: "\(Int(calorieTarget))",
                category: .calories,
                progress: calorieTarget > 0 ? calories / calorieTarget : 0
            )
        }
        .padding(.horizontal, Theme.Spacing.md)
    }

    // MARK: - Quick Log Buttons

    private var quickLogButtons: some View {
        HStack(spacing: Theme.Spacing.sm) {
            quickLogButton("Protein", icon: "plus", color: Theme.Semantic.protein(for: scheme)) {
                addToLog(protein: 25)
            }
            quickLogButton("Water", icon: "drop.fill", color: Theme.Semantic.water(for: scheme)) {
                addToLog(water: 0.25)
            }
            quickLogButton("Meal", icon: "fork.knife", color: Theme.Accent.primary(for: scheme)) {
                addToLog(protein: 30, calories: 450, fiber: 6)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
    }

    private func quickLogButton(
        _ title: String,
        icon: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            HapticManager.medium()
            withAnimation(Theme.Motion.spring) {
                action()
            }
        } label: {
            VStack(spacing: Theme.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(color)
                Text(title)
                    .font(Typography.caption)
                    .foregroundStyle(Theme.Text.secondary(for: scheme))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.sm + 2)
            .background(Theme.Surface.glass(for: scheme))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .stroke(Theme.Border.glass(for: scheme), lineWidth: Theme.glassBorderWidth)
            )
        }
        .buttonStyle(GlassPressStyle())
    }

    // MARK: - Grocery Section

    private var grocerySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("GROCERY LIST")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Theme.Text.tertiary(for: scheme))
                    .tracking(1.2)

                Text("\(pantryItems.count) items")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.Text.tertiary(for: scheme))

                Spacer()

                Button {
                    showFullGrocery = true
                } label: {
                    Text("View all")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.violet.opacity(0.6))
                }
            }

            // Inline grocery items
            if pantryItems.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "cart")
                        .font(.system(size: 28))
                        .foregroundStyle(Theme.Text.tertiary(for: scheme))
                    Text("Your grocery list is empty")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.Text.tertiary(for: scheme))
                    Text("Add items below or scan a barcode")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.Text.tertiary(for: scheme))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                ForEach(pantryItems.prefix(8)) { item in
                    HStack(spacing: 12) {
                        Image(systemName: item.category.icon)
                            .font(.system(size: 12))
                            .foregroundStyle(Color.violet.opacity(0.5))
                            .frame(width: 20)

                        Text(item.name)
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.Text.primary)

                        Spacer()

                        Button {
                            HapticManager.light()
                            withAnimation {
                                modelContext.delete(item)
                            }
                        } label: {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 18))
                                .foregroundStyle(Color.violet.opacity(0.4))
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            // Add item input
            HStack(spacing: 10) {
                Image(systemName: "plus")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.violet.opacity(0.5))

                TextField("Add an item...", text: $newItemText)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.Text.primary)
                    .onSubmit {
                        addGroceryItem()
                    }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(Theme.Surface.glass(for: scheme))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.Surface.glass(for: scheme))
        )
        .padding(.horizontal, Theme.Spacing.md)
        .sheet(isPresented: $showFullGrocery) {
            GroceryListView()
        }
    }

    private func addGroceryItem() {
        let text = newItemText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        let item = PantryItem(name: text)
        modelContext.insert(item)
        newItemText = ""
        HapticManager.light()
    }

    // MARK: - Mira Suggestion

    private var miraSuggestion: some View {
        InteractiveGlassCard(action: {}) {
            HStack(alignment: .top, spacing: Theme.Spacing.md) {
                MiraWaveform(state: .speaking, size: .compact)
                    .padding(.top, Theme.Spacing.xs)

                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Mira's suggestion")
                        .font(Typography.caption)
                        .foregroundStyle(Theme.Text.tertiary(for: scheme))
                    Text(miraSuggestionText)
                        .font(Typography.bodyMedium)
                        .foregroundStyle(Theme.Text.primary)
                }
            }
            .padding(Theme.Spacing.md)
        }
        .padding(.horizontal, Theme.Spacing.md)
    }

    private var miraSuggestionText: String {
        let hour = Calendar.current.component(.hour, from: .now)
        let worries = profile?.worries ?? []
        let training = profile?.trainingLevel ?? .none
        let isOnMed = profile?.medication != nil

        // Priority 1: Protein deficit (the core metric)
        if proteinDeficit > 50 {
            if worries.contains(.losingMuscle) {
                return "You're \(proteinDeficit)g short on protein. Since muscle preservation is your focus, this is the one number to close today. A chicken breast (31g) and Greek yogurt (15g) gets you halfway."
            }
            return "\(proteinDeficit)g of protein left today. Two solid meals will do it. Try a grilled chicken bowl for lunch and salmon for dinner."
        }

        if proteinDeficit > 20 {
            if training == .lifts {
                return "\(proteinDeficit)g to go. Since you're lifting, getting this in before bed matters. A protein shake (25g) or cottage cheese (14g) will close the gap."
            }
            return "\(proteinDeficit)g left. A protein shake or a can of tuna with crackers would close the gap in one sitting."
        }

        // Priority 2: Hydration
        if water < waterTarget * 0.5 {
            if isOnMed {
                return "You're behind on hydration. Your medication can suppress thirst, so you may not feel it. Try a glass now."
            }
            if worries.contains(.lowEnergy) {
                return "You're behind on water. Dehydration is one of the biggest energy killers. A glass now will help more than coffee."
            }
            return "You're behind on hydration. Try to get a glass in. It helps with energy, focus, and recovery."
        }

        // Priority 3: No food logged yet
        if protein == 0 && hour < 12 {
            if worries.contains(.nausea) || isOnMed {
                return "Morning is a great time to start, even if appetite is low. A smoothie or scrambled eggs are easy to get down."
            }
            return "Start your day with protein. Eggs (18g for 3), overnight oats with Greek yogurt (32g), or a quick smoothie (30g)."
        }

        if protein == 0 && hour >= 12 {
            return "You haven't logged any protein yet. A quick chicken breast (31g) or tuna wrap (28g) will get you started."
        }

        // Priority 4: Protein hit - personalized encouragement
        if proteinDeficit <= 0 {
            if worries.contains(.losingMuscle) {
                return "Protein target hit. Your muscles are getting what they need today. Focus on hydration and rest."
            }
            if worries.contains(.regainingWeight) {
                return "Great work on protein. Staying consistent with this is how you maintain results long term."
            }
            if training == .lifts {
                return "Protein target hit. If you're training today, you're fueled and ready. Recovery starts with what you ate."
            }
            return "You've hit your protein target. Focus on hydration and vegetables for the rest of the day."
        }

        return "Almost there! Just \(proteinDeficit)g more. A cup of cottage cheese (14g) or string cheese with almonds (13g) will do it."
    }

    // MARK: - Symptom Quick Log

    private var symptomQuickLog: some View {
        SymptomQuickLog()
            .padding(.horizontal, Theme.Spacing.md)
    }

    // MARK: - Data Helpers

    private func addToLog(protein: Double = 0, calories: Double = 0, water: Double = 0, fiber: Double = 0) {
        if let log = todayLog {
            log.proteinGrams += protein
            log.caloriesConsumed += calories
            log.waterLiters += water
            log.fiberGrams += fiber
        } else {
            let log = NutritionLog(
                date: .now,
                proteinGrams: protein,
                caloriesConsumed: calories,
                waterLiters: water,
                fiberGrams: fiber
            )
            modelContext.insert(log)
        }
        HapticManager.success()
    }

    // MARK: - Macro Tile

    private func macroTile(
        _ title: String,
        value: String,
        unit: String,
        target: String,
        category: ProgressCategory,
        progress: Double
    ) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text(title)
                    .font(Typography.caption)
                    .foregroundStyle(Theme.Text.tertiary(for: scheme))

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(value)
                        .font(Typography.monoMedium)
                        .foregroundStyle(Theme.Text.primary)
                    Text(unit)
                        .font(Typography.caption)
                        .foregroundStyle(Theme.Text.secondary(for: scheme))
                }

                ProgressBar(progress: progress, category: category, height: 4)

                Text(target)
                    .font(Typography.caption)
                    .foregroundStyle(Theme.Text.tertiary(for: scheme))
            }
            .padding(Theme.Spacing.sm + 2)
        }
    }
}
