import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.modelContext) private var modelContext
    @State private var showProfile = false
    @State private var showFullGrocery = false
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
                proteinHeroCard
                macroTiles
                quickLogButtons
                grocerySection
                InjectionCycleBar()
                    .padding(.horizontal, Theme.Spacing.md)
                miraSuggestion
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
                showProfile = true
            } label: {
                MiraWaveform(state: .idle, size: .hero)
                    .frame(height: 32)
                    .scaleEffect(0.6, anchor: .trailing)
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
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("GROCERY LIST")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.25))
                    .tracking(1.2)
                Spacer()
                Button {
                    showFullGrocery = true
                } label: {
                    Text("View all")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.violet.opacity(0.6))
                }
            }

            // Color-coded category cards
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ], spacing: 8) {
                groceryCategory("Protein", icon: "flame.fill", count: 5, color: Color(hex: 0xA78BFA), items: ["Chicken breast", "Greek yogurt", "Eggs", "Salmon", "Whey protein"])
                groceryCategory("Produce", icon: "carrot.fill", count: 6, color: Color(hex: 0x34D399), items: ["Broccoli", "Spinach", "Bananas", "Berries", "Avocados"])
                groceryCategory("Grains", icon: "leaf.fill", count: 3, color: Color(hex: 0xFBBF24), items: ["Brown rice", "Oats", "Sweet potatoes"])
                groceryCategory("Pantry", icon: "bag.fill", count: 4, color: Color(hex: 0x38BDF8), items: ["Hemp seeds", "Almond butter", "Chia seeds", "Ginger tea"])
            }

            // Quick add from pantry
            if !pantryItems.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "refrigerator.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.2))
                    Text("\(pantryItems.count) items in pantry")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.25))
                }
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .sheet(isPresented: $showFullGrocery) {
            GroceryListView()
        }
    }

    private func groceryCategory(_ name: String, icon: String, count: Int, color: Color, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(color)
                Text(name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
                Text("\(count)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(color.opacity(0.6))
            }

            VStack(alignment: .leading, spacing: 3) {
                ForEach(items.prefix(3), id: \.self) { item in
                    Text(item)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.4))
                        .lineLimit(1)
                }
                if items.count > 3 {
                    Text("+\(items.count - 3) more")
                        .font(.system(size: 11))
                        .foregroundStyle(color.opacity(0.4))
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(color.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(color.opacity(0.1), lineWidth: 0.5)
        )
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
        if proteinDeficit > 30 {
            return "You're \(proteinDeficit)g behind on protein. Greek yogurt + hemp seeds closes the gap in one snack."
        } else if proteinDeficit > 0 {
            return "Almost there! Just \(proteinDeficit)g more protein. A quick protein shake would do it."
        } else if water < waterTarget * 0.5 {
            return "You're behind on hydration. GLP-1s suppress thirst. Try to drink a glass now."
        } else {
            return "Great progress today! Keep it up and you'll hit all your targets."
        }
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
