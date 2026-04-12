import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.modelContext) private var modelContext
    @State private var showProfile = false
    @Query private var profiles: [UserProfile]
    @Query(filter: #Predicate<NutritionLog> { log in
        log.date > Date.distantPast
    }, sort: \NutritionLog.date, order: .reverse) private var logs: [NutritionLog]

    private var profile: UserProfile? { profiles.first }
    private var todayLog: NutritionLog? {
        logs.first { Calendar.current.isDateInToday($0.date) }
    }

    private var isGLP1: Bool { profile?.medication != nil }

    private var protein: Double { todayLog?.proteinGrams ?? 0 }
    private var proteinTarget: Double { Double(profile?.proteinTargetGrams ?? 140) }
    private var calories: Double { todayLog?.caloriesConsumed ?? 0 }
    private var calorieTarget: Double { Double(profile?.calorieTarget ?? 1800) }
    private var water: Double { todayLog?.waterLiters ?? 0 }
    private var waterTarget: Double { profile?.waterTargetLiters ?? 2.5 }
    private var fiber: Double { todayLog?.fiberGrams ?? 0 }
    private var fiberTarget: Double { Double(profile?.fiberTargetGrams ?? 25) }

    private var proteinDeficit: Int {
        max(0, Int(proteinTarget - protein))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.sectionGap) {
                headerBar
                greetingBlock
                StreakDots(activeDays: [0, 1, 2, 4, 5])
                miraSuggestion
                glanceTiles
                bodyComposition
                medicationOrGoalSlot
                Spacer(minLength: 80)
            }
        }
        .themeBackground()
        .navigationBarHidden(true)
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack {
            Text("MEMORYAISLE")
                .font(Typography.label)
                .letterSpaced(2.0)
                .foregroundStyle(Theme.Accent.ghost(for: scheme))

            Spacer()

            Button {
                showProfile = true
            } label: {
                Circle()
                    .fill(Theme.Accent.subtle(for: scheme))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.Text.tertiary(for: scheme))
                    )
            }
        }
        .padding(.horizontal, Theme.Spacing.screenH)
        .padding(.top, Theme.Spacing.sm)
        .sheet(isPresented: $showProfile) {
            ProfileView()
        }
    }

    // MARK: - Greeting Block

    private var greetingBlock: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Text(greeting)
                .font(Typography.bodyMedium)
                .foregroundStyle(Theme.Text.tertiary(for: scheme))

            greetingHeadline
        }
        .frame(maxWidth: .infinity)
    }

    private var greetingHeadline: some View {
        let name = profile?.name ?? ""
        let displayName = name.isEmpty ? "" : ", \(name)"
        return Text(headlinePrefix)
            .font(Typography.displayMedium)
            .foregroundStyle(Theme.Text.primary)
        + Text(displayName)
            .font(Typography.displayMedium)
            .foregroundStyle(Theme.Accent.primary(for: scheme))
    }

    private var headlinePrefix: String {
        let hour = Calendar.current.component(.hour, from: .now)
        if hour < 12 { return "Let's build today" }
        if hour < 17 { return "Keep it going" }
        if hour < 22 { return "Close it out" }
        return "Rest well"
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        if hour < 5 { return "Late night" }
        if hour < 12 { return "Good morning" }
        if hour < 17 { return "Good afternoon" }
        if hour < 22 { return "Good evening" }
        return "Late night"
    }

    // MARK: - Mira Suggestion

    private var miraSuggestion: some View {
        InteractiveGlassCard(action: {}) {
            HStack(alignment: .top, spacing: Theme.Spacing.md) {
                MiraWaveform(state: .speaking, size: .compact)
                    .padding(.top, Theme.Spacing.xs)

                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Mira")
                        .font(Typography.label)
                        .foregroundStyle(Theme.Accent.primary(for: scheme))
                    Text(miraSuggestionText)
                        .font(Typography.bodyMedium)
                        .foregroundStyle(Theme.Text.secondary(for: scheme))
                }
            }
            .padding(Theme.Spacing.cardPad)
        }
        .padding(.horizontal, Theme.Spacing.screenH)
    }

    private var miraSuggestionText: String {
        if isGLP1 {
            if proteinDeficit > 30 {
                return "You're \(proteinDeficit)g behind on protein. Greek yogurt + hemp seeds closes the gap."
            } else if water < waterTarget * 0.5 {
                return "You're behind on hydration. GLP-1s suppress thirst cues -- try a glass now."
            } else {
                return "Great progress today. Keep hitting your protein window and stay hydrated."
            }
        } else {
            if proteinDeficit > 30 {
                return "You're \(proteinDeficit)g behind on protein. A quick snack can close the gap."
            } else {
                return "Solid day so far. Keep building on your streak!"
            }
        }
    }

    // MARK: - Glance Tiles

    private var glanceTiles: some View {
        HStack(spacing: Theme.Spacing.cardGap) {
            glanceTile(
                "PROTEIN",
                value: "\(Int(protein))",
                unit: "g",
                target: "\(Int(proteinTarget))g",
                color: Theme.Semantic.protein(for: scheme),
                progress: proteinTarget > 0 ? protein / proteinTarget : 0
            )
            glanceTile(
                "CALORIES",
                value: "\(Int(calories))",
                unit: "",
                target: "\(Int(calorieTarget))",
                color: Theme.Semantic.calories(for: scheme),
                progress: calorieTarget > 0 ? calories / calorieTarget : 0
            )
            glanceTile(
                "WATER",
                value: String(format: "%.1f", water),
                unit: "L",
                target: String(format: "%.1fL", waterTarget),
                color: Theme.Semantic.water(for: scheme),
                progress: waterTarget > 0 ? water / waterTarget : 0
            )
        }
        .padding(.horizontal, Theme.Spacing.screenH)
    }

    private func glanceTile(
        _ title: String,
        value: String,
        unit: String,
        target: String,
        color: Color,
        progress: Double
    ) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text(title)
                    .font(Typography.micro)
                    .letterSpaced(0.8)
                    .foregroundStyle(Theme.Text.tertiary(for: scheme))

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(value)
                        .font(Typography.dataSmall)
                        .tabularFigures()
                        .foregroundStyle(Theme.Text.primary)
                    if !unit.isEmpty {
                        Text(unit)
                            .font(Typography.caption)
                            .foregroundStyle(Theme.Text.secondary(for: scheme))
                    }
                }

                ProgressBar(progress: progress, category: categoryFor(title), height: 4)

                Text(target)
                    .font(Typography.caption)
                    .foregroundStyle(Theme.Text.hint(for: scheme))
            }
            .padding(Theme.Spacing.sm + 4)
        }
    }

    private func categoryFor(_ title: String) -> ProgressCategory {
        switch title {
        case "PROTEIN": .protein
        case "CALORIES": .calories
        case "WATER": .water
        default: .fiber
        }
    }

    // MARK: - Body Composition

    private var bodyComposition: some View {
        BodyCompositionCard(
            leanMassLbs: 128.4,
            bodyFatPercent: 24.2,
            leanMassDelta: 0.3,
            bodyFatDelta: -0.8,
            weightHistory: [172, 171, 170.5, 170, 169.2, 169, 168.5],
            leanMassHistory: [127.8, 127.9, 128.0, 128.1, 128.2, 128.3, 128.4]
        )
        .padding(.horizontal, Theme.Spacing.screenH)
    }

    // MARK: - Medication / Weekly Goal Slot

    @ViewBuilder
    private var medicationOrGoalSlot: some View {
        if isGLP1 {
            MedicationCycleBar(
                medicationName: profile?.medication?.rawValue ?? "Medication",
                doseLabel: profile?.doseAmount ?? "",
                currentDay: currentCycleDay,
                totalDays: 7
            )
            .padding(.horizontal, Theme.Spacing.screenH)
        } else {
            WeeklyGoalCard(
                goalLabel: "Lose 0.5 lbs/week",
                isOnTrack: proteinDeficit < 20
            )
            .padding(.horizontal, Theme.Spacing.screenH)
        }
    }

    private var currentCycleDay: Int {
        guard let injectionDay = profile?.injectionDay else { return 1 }
        let today = Calendar.current.component(.weekday, from: .now)
        let elapsed = (today - injectionDay + 7) % 7
        return elapsed + 1
    }

    // MARK: - Data Helpers

    private func addToLog(
        protein: Double = 0,
        calories: Double = 0,
        water: Double = 0,
        fiber: Double = 0
    ) {
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
}
