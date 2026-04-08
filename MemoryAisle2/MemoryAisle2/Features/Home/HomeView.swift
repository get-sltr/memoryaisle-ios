import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.modelContext) private var modelContext
    @State private var showProfile = false
    @State private var showFullGrocery = false
    @State private var showCalendar = false
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
            .padding(.horizontal, Theme.Spacing.md)

            // Horizontal scroll -- minimal
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(pantryCategoryCounts, id: \.name) { cat in
                        groceryPill(cat.name, icon: cat.icon, count: cat.count, gradientColors: cat.colors)
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
            }
        }
        .sheet(isPresented: $showFullGrocery) {
            GroceryListView()
        }
    }

    private func groceryPill(_ name: String, icon: String, count: Int, gradientColors: [Color]) -> some View {
        Button {
            showFullGrocery = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(.white)

                Text(name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)

                Text("\(count)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                    .opacity(0.25)
            )
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(gradientColors[0].opacity(0.3), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private var pantryCategoryCounts: [(name: String, icon: String, count: Int, colors: [Color])] {
        let grouped = Dictionary(grouping: pantryItems, by: \.category)
        let mapping: [(PantryCategory, String, [Color])] = [
            (.protein, "flame.fill", [Color(hex: 0xA78BFA), Color(hex: 0x7C3AED)]),
            (.produce, "carrot.fill", [Color(hex: 0x34D399), Color(hex: 0x059669)]),
            (.dairy, "cup.and.saucer.fill", [Color(hex: 0x38BDF8), Color(hex: 0x0EA5E9)]),
            (.grains, "leaf.fill", [Color(hex: 0xFBBF24), Color(hex: 0xD97706)]),
            (.frozen, "snowflake", [Color(hex: 0x67E8F9), Color(hex: 0x22D3EE)]),
            (.pantryStaple, "bag.fill", [Color(hex: 0xFCA5A5), Color(hex: 0xF87171)]),
        ]
        return mapping.compactMap { cat, icon, colors in
            let count = grouped[cat]?.count ?? 0
            guard count > 0 else { return nil }
            return (name: cat.rawValue, icon: icon, count: count, colors: colors)
        }
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

    private var isOnGLP1: Bool {
        profile?.medication != nil
    }

    private var miraSuggestionText: String {
        let hour = Calendar.current.component(.hour, from: .now)

        if proteinDeficit > 80 {
            return "You need \(proteinDeficit)g more protein today. That's about 3 meals worth. Start with a chicken breast (31g), then a protein shake (25g), and finish with salmon for dinner (23g)."
        } else if proteinDeficit > 50 {
            return "\(proteinDeficit)g to go. Two solid meals will do it. Try a grilled chicken bowl (45g protein) for lunch and Greek yogurt with hemp seeds (24g) as a snack."
        } else if proteinDeficit > 20 {
            return "\(proteinDeficit)g left. A protein shake (25g) or a can of tuna with crackers (30g) would close the gap in one sitting."
        } else if proteinDeficit > 0 {
            return "Almost there! Just \(proteinDeficit)g more. A cup of cottage cheese (14g) or a handful of almonds with a string cheese (13g) will do it."
        } else if water < waterTarget * 0.5 {
            if isOnGLP1 {
                return "You're behind on hydration. GLP-1s can suppress thirst, so you may not feel it. Try a glass now."
            } else {
                return "You're behind on hydration. Try to get a glass of water in. Staying hydrated helps with energy and focus."
            }
        } else if protein == 0 && hour < 12 {
            if isOnGLP1 {
                return "Morning is a great time to start on protein, even if appetite is low. A smoothie or eggs are easy to get down."
            } else {
                return "Start your day with protein. Eggs (18g for 3), overnight oats with Greek yogurt (32g), or a smoothie (30g)."
            }
        } else if protein == 0 && hour >= 12 {
            return "You haven't logged any protein yet. A quick chicken breast (31g) or tuna wrap (28g) will get you going."
        } else {
            return "You've hit your protein target. Focus on hydration and vegetables for the rest of the day."
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
