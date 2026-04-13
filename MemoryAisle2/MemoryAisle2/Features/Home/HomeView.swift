import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.modelContext) private var modelContext
    @Binding var showMenu: Bool

    @Query private var profiles: [UserProfile]
    @Query(sort: \NutritionLog.date, order: .reverse) private var logs: [NutritionLog]
    @Query(sort: \BodyComposition.date, order: .reverse) private var bodyCompRecords: [BodyComposition]
    @Query(sort: \Meal.createdAt, order: .reverse) private var meals: [Meal]

    private var profile: UserProfile? { profiles.first }
    private var todayLog: NutritionLog? {
        logs.first { Calendar.current.isDateInToday($0.date) }
    }
    private var latestBodyComp: BodyComposition? { bodyCompRecords.first }
    private var earliestBodyComp: BodyComposition? { bodyCompRecords.last }

    private var tonightsDinner: Meal? {
        meals.first { $0.mealType == .dinner }
    }

    private var isGLP1: Bool { profile?.medication != nil }

    private var protein: Double { todayLog?.proteinGrams ?? 0 }
    private var proteinTarget: Double { Double(profile?.proteinTargetGrams ?? 140) }
    private var calories: Double { todayLog?.caloriesConsumed ?? 0 }
    private var calorieTarget: Double { Double(profile?.calorieTarget ?? 1800) }

    private var currentWeightLbs: Double? { latestBodyComp?.weightLbs }
    private var startWeightLbs: Double? {
        earliestBodyComp?.weightLbs ?? profile?.weightLbs
    }
    private var goalWeightLbs: Double? { profile?.goalWeightLbs }

    private var proteinDeficit: Int {
        max(0, Int(proteinTarget - protein))
    }

    // Streak: last 7 days, active if protein target met
    private var streakActiveDays: [Int] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        var active: [Int] = []
        for offset in 0..<7 {
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { continue }
            let hit = logs.contains { log in
                cal.isDate(log.date, inSameDayAs: day) && log.proteinGrams >= proteinTarget
            }
            if hit { active.append(6 - offset) }
        }
        return active
    }

    private var streakLabel: String {
        let count = streakActiveDays.count
        if count == 0 { return "Ready when you are" }
        if count == 7 { return "Perfect week" }
        return "\(count) of 7 days this week"
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: Theme.Spacing.sectionGap) {
                headerBar
                greetingBlock
                streakBlock
                miraCard
                glanceTiles
                tonightsMealRow
                bodyCompositionSlot
                medicationOrGoalSlot
                Spacer(minLength: 80)
            }
            .padding(.top, Theme.Spacing.sm)
        }
        .themeBackground()
        .navigationBarHidden(true)
    }

    // MARK: - Header bar

    private var headerBar: some View {
        HStack {
            Button {
                HapticManager.light()
                showMenu = true
            } label: {
                Text("MEMORYAISLE")
                    .font(Typography.label)
                    .letterSpaced(2.0)
                    .foregroundStyle(Theme.Accent.ghost(for: scheme))
            }
            .accessibilityLabel("Open menu")

            Spacer()

            Circle()
                .fill(Theme.Accent.subtle(for: scheme))
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.Text.tertiary(for: scheme))
                )
                .accessibilityLabel("Profile")
        }
        .padding(.horizontal, Theme.Spacing.screenH)
    }

    // MARK: - Greeting block

    private var greetingBlock: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Text(greetingLine)
                .font(Typography.bodyMedium)
                .foregroundStyle(Theme.Text.tertiary(for: scheme))

            headlineWithAccent
        }
        .frame(maxWidth: .infinity)
    }

    private var greetingLine: String {
        let hour = Calendar.current.component(.hour, from: .now)
        if hour < 5 { return "Late night" }
        if hour < 12 { return "Good morning" }
        if hour < 17 { return "Good afternoon" }
        if hour < 22 { return "Good evening" }
        return "Late night"
    }

    private var headlineWithAccent: some View {
        HStack(spacing: 0) {
            Text(headlineLeading)
                .foregroundStyle(Theme.Text.primary)
            Text(headlineAccent)
                .foregroundStyle(Theme.Accent.primary(for: scheme))
        }
        .font(Typography.displayMedium)
    }

    private var headlineLeading: String {
        let hour = Calendar.current.component(.hour, from: .now)
        if hour < 12 { return "Let's build " }
        if hour < 17 { return "Keep it " }
        if hour < 22 { return "Close it " }
        return "Rest "
    }

    private var headlineAccent: String {
        let hour = Calendar.current.component(.hour, from: .now)
        if hour < 12 { return "today" }
        if hour < 17 { return "going" }
        if hour < 22 { return "out" }
        return "well"
    }

    // MARK: - Streak block

    private var streakBlock: some View {
        VStack(spacing: Theme.Spacing.sm) {
            StreakDots(activeDays: Set(streakActiveDays))
            Text(streakLabel)
                .font(Typography.caption)
                .foregroundStyle(Theme.Text.tertiary(for: scheme))
        }
    }

    // MARK: - Mira insight card

    private var miraCard: some View {
        GlassCardStrong {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack(alignment: .top, spacing: Theme.Spacing.md) {
                    MiraWaveform(state: .speaking, size: .compact)
                        .padding(.top, Theme.Spacing.xs)

                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text("Mira")
                            .font(Typography.label)
                            .foregroundStyle(Theme.Accent.primary(for: scheme))
                        Text(miraMessage)
                            .font(Typography.bodyMedium)
                            .foregroundStyle(Theme.Text.secondary(for: scheme))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }

                HStack(spacing: Theme.Spacing.sm) {
                    ForEach(miraActionChips, id: \.self) { chip in
                        chipButton(chip)
                    }
                }
            }
            .padding(Theme.Spacing.cardPad)
        }
        .padding(.horizontal, Theme.Spacing.screenH)
    }

    private var miraMessage: String {
        if proteinDeficit > 30 {
            if isGLP1 {
                return "You're \(proteinDeficit)g shy of your protein floor. Greek yogurt with hemp seeds closes it quick."
            }
            return "You're \(proteinDeficit)g shy of your protein floor. A quick snack closes it."
        }
        if let weight = currentWeightLbs, let goal = goalWeightLbs, abs(weight - goal) < 1 {
            return "You are right at your goal weight. Take a second and feel that."
        }
        return "Solid start. Keep your protein steady and the rest takes care of itself."
    }

    private var miraActionChips: [String] {
        if isGLP1 {
            return ["Sounds good", "Show me options", "I already ate"]
        }
        return ["Sounds good", "Swap it", "I'm eating out"]
    }

    private func chipButton(_ title: String) -> some View {
        Button {
            HapticManager.light()
        } label: {
            Text(title)
                .font(Typography.bodySmall)
                .foregroundStyle(Theme.Text.secondary(for: scheme))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Theme.Accent.subtle(for: scheme))
                )
                .overlay(
                    Capsule()
                        .stroke(Theme.Border.glass(for: scheme), lineWidth: Theme.glassBorderWidth)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    // MARK: - Glance tiles

    private var glanceTiles: some View {
        HStack(spacing: Theme.Spacing.cardGap) {
            glanceTile(
                label: "PROTEIN",
                value: "\(Int(protein))",
                unit: "g",
                target: "\(Int(proteinTarget))g",
                category: .protein,
                progress: proteinTarget > 0 ? protein / proteinTarget : 0
            )
            glanceTile(
                label: "CALORIES",
                value: "\(Int(calories))",
                unit: "",
                target: "\(Int(calorieTarget))",
                category: .calories,
                progress: calorieTarget > 0 ? calories / calorieTarget : 0
            )
            weightTile
        }
        .padding(.horizontal, Theme.Spacing.screenH)
    }

    private func glanceTile(
        label: String,
        value: String,
        unit: String,
        target: String,
        category: ProgressCategory,
        progress: Double
    ) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text(label)
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

                ProgressBar(progress: progress, category: category, height: 4)

                Text(target)
                    .font(Typography.caption)
                    .foregroundStyle(Theme.Text.hint(for: scheme))
            }
            .padding(Theme.Spacing.sm + 4)
        }
    }

    private var weightTile: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("WEIGHT")
                    .font(Typography.micro)
                    .letterSpaced(0.8)
                    .foregroundStyle(Theme.Text.tertiary(for: scheme))

                if let current = currentWeightLbs {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(String(format: "%.1f", current))
                            .font(Typography.dataSmall)
                            .tabularFigures()
                            .foregroundStyle(Theme.Text.primary)
                        Text("lbs")
                            .font(Typography.caption)
                            .foregroundStyle(Theme.Text.secondary(for: scheme))
                    }
                    if let delta = weightDeltaText {
                        Text(delta)
                            .font(Typography.caption)
                            .foregroundStyle(Theme.Semantic.onTrack(for: scheme))
                    } else if let goal = goalWeightLbs {
                        Text("\(Int(goal)) goal")
                            .font(Typography.caption)
                            .foregroundStyle(Theme.Text.hint(for: scheme))
                    }
                } else {
                    Text("—")
                        .font(Typography.dataSmall)
                        .foregroundStyle(Theme.Text.tertiary(for: scheme))
                    Text("Log your first check-in")
                        .font(Typography.caption)
                        .foregroundStyle(Theme.Text.hint(for: scheme))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(Theme.Spacing.sm + 4)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var weightDeltaText: String? {
        guard let current = currentWeightLbs,
              let start = startWeightLbs,
              let goal = goalWeightLbs else { return nil }
        let loss = goal < start
        let delta = loss ? start - current : current - start
        if delta <= 0 { return nil }
        let rounded = String(format: "%.1f", delta)
        return loss ? "-\(rounded) lbs" : "+\(rounded) lbs"
    }

    // MARK: - Tonight's meal row

    @ViewBuilder
    private var tonightsMealRow: some View {
        if let meal = tonightsDinner {
            GlassCard {
                HStack(spacing: Theme.Spacing.md) {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Theme.Accent.subtle(for: scheme))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: "fork.knife")
                                .font(.system(size: 16))
                                .foregroundStyle(Theme.Accent.primary(for: scheme))
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text("TONIGHT'S MEAL")
                            .font(Typography.micro)
                            .letterSpaced(0.8)
                            .foregroundStyle(Theme.Text.tertiary(for: scheme))
                        Text(meal.name)
                            .font(Typography.bodyMedium)
                            .foregroundStyle(Theme.Text.primary)
                        Text("\(Int(meal.proteinGrams))g protein · \(Int(meal.caloriesTotal)) cal")
                            .font(Typography.caption)
                            .foregroundStyle(Theme.Text.tertiary(for: scheme))
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.Text.hint(for: scheme))
                }
                .padding(.vertical, Theme.Spacing.md)
                .padding(.horizontal, Theme.Spacing.cardPad)
            }
            .padding(.horizontal, Theme.Spacing.screenH)
        } else {
            GlassCard {
                HStack(spacing: Theme.Spacing.md) {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Theme.Accent.subtle(for: scheme))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: "fork.knife")
                                .font(.system(size: 16))
                                .foregroundStyle(Theme.Accent.ghost(for: scheme))
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text("TONIGHT'S MEAL")
                            .font(Typography.micro)
                            .letterSpaced(0.8)
                            .foregroundStyle(Theme.Text.tertiary(for: scheme))
                        Text("No dinner planned yet")
                            .font(Typography.bodyMedium)
                            .foregroundStyle(Theme.Text.secondary(for: scheme))
                    }

                    Spacer()
                }
                .padding(.vertical, Theme.Spacing.md)
                .padding(.horizontal, Theme.Spacing.cardPad)
            }
            .padding(.horizontal, Theme.Spacing.screenH)
        }
    }

    // MARK: - Body composition slot

    @ViewBuilder
    private var bodyCompositionSlot: some View {
        if bodyCompRecords.isEmpty {
            GlassCard {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("BODY COMPOSITION")
                        .font(Typography.micro)
                        .letterSpaced(0.8)
                        .foregroundStyle(Theme.Text.tertiary(for: scheme))

                    Text("No check-ins yet")
                        .font(Typography.bodyMedium)
                        .foregroundStyle(Theme.Text.secondary(for: scheme))

                    Text("Your lean mass, body fat, and weight trend will appear here after your first weekly check-in.")
                        .font(Typography.caption)
                        .foregroundStyle(Theme.Text.hint(for: scheme))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(Theme.Spacing.cardPad)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, Theme.Spacing.screenH)
        } else if let latest = latestBodyComp {
            BodyCompositionCard(
                leanMassLbs: latest.computedLeanMass,
                bodyFatPercent: latest.bodyFatPercent ?? 0,
                leanMassDelta: leanMassDelta,
                bodyFatDelta: bodyFatDelta,
                weightHistory: weightHistory,
                leanMassHistory: leanMassHistory
            )
            .padding(.horizontal, Theme.Spacing.screenH)
        }
    }

    private var leanMassDelta: Double {
        guard let latest = latestBodyComp, let earliest = earliestBodyComp, latest.id != earliest.id else {
            return 0
        }
        return latest.computedLeanMass - earliest.computedLeanMass
    }

    private var bodyFatDelta: Double {
        guard let latest = latestBodyComp, let earliest = earliestBodyComp,
              let latestBF = latest.bodyFatPercent, let earliestBF = earliest.bodyFatPercent,
              latest.id != earliest.id else {
            return 0
        }
        return latestBF - earliestBF
    }

    private var weightHistory: [Double] {
        bodyCompRecords.reversed().suffix(7).map { $0.weightLbs }
    }

    private var leanMassHistory: [Double] {
        bodyCompRecords.reversed().suffix(7).map { $0.computedLeanMass }
    }

    // MARK: - Medication / weekly goal slot

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
                goalLabel: weeklyGoalLabel,
                isOnTrack: proteinDeficit < 20
            )
            .padding(.horizontal, Theme.Spacing.screenH)
        }
    }

    private var weeklyGoalLabel: String {
        guard let start = startWeightLbs, let goal = goalWeightLbs else {
            return "Set your weekly goal"
        }
        if goal < start {
            return "Lose 0.5 lbs/week"
        } else if goal > start {
            return "Gain 0.5 lbs/week"
        }
        return "Maintain your weight"
    }

    private var currentCycleDay: Int {
        guard let injectionDay = profile?.injectionDay else { return 1 }
        let today = Calendar.current.component(.weekday, from: .now)
        let elapsed = (today - injectionDay + 7) % 7
        return elapsed + 1
    }
}
