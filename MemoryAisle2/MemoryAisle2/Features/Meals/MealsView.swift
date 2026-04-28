import SwiftData
import SwiftUI

/// Editorial Meals tab. Masthead → cycle marker → hero → day rail →
/// meal rows. Tap a row to expand its ingredients/instructions.
struct MealsView: View {
    let mode: MAMode
    let onTapWordmark: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(SubscriptionManager.self) private var subscriptionManager
    @Query private var profiles: [UserProfile]
    @Query(sort: \MealPlan.date, order: .reverse) private var plans: [MealPlan]
    @Query(sort: \MedicationProfile.startDate, order: .reverse) private var medications: [MedicationProfile]
    @Query private var jobs: [MealGenerationJob]

    @State private var selectedDay: Weekday = Weekday.from(date: .now)
    @State private var expandedMealId: String? = nil
    @State private var localError: String? = nil

    private var profile: UserProfile? { profiles.first }
    private var medication: MedicationProfile? { medications.first }

    private var inFlightJob: MealGenerationJob? {
        jobs.first { $0.isInFlight }
    }

    private var lastTerminalJob: MealGenerationJob? {
        jobs
            .filter { $0.isTerminal }
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
            .first
    }

    private var selectedDate: Date {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let todayWeekday = Weekday.from(date: today)
        let diff = selectedDay.calendarWeekday - todayWeekday.calendarWeekday
        return cal.date(byAdding: .day, value: diff, to: today) ?? today
    }

    private var planForSelectedDay: MealPlan? {
        plans.first { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) && $0.isActive }
    }

    private var meals: [Meal] {
        (planForSelectedDay?.meals ?? []).sorted { sortKey(for: $0) < sortKey(for: $1) }
    }

    private var lastJobFailedSelectedDay: Bool {
        guard let job = lastTerminalJob,
              (job.status == .partial || job.status == .failed) else { return false }
        let cal = Calendar.current
        // The job's lastError isn't keyed by date in the model, but we can
        // infer: if the job is partial and the selected date falls in [first,
        // first+totalDays) and there's no plan for that date, the day failed.
        guard let lastDay = cal.date(byAdding: .day, value: job.totalDays - 1, to: job.firstDate) else { return false }
        let inRange = selectedDate >= job.firstDate && selectedDate <= lastDay
        return inRange && planForSelectedDay == nil
    }

    var body: some View {
        switch mode {
        case .day:   dayLayout
        case .night: nightLayout
        }
    }

    private var dayLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            Masthead(
                wordmark: "MEALS",
                trailing: "WEEK · \(currentWeekNumber)",
                onTapWordmark: onTapWordmark
            )
            .padding(.bottom, 24)

            Text(sectionLabel)
                .font(Theme.Editorial.Typography.capsBold(10))
                .tracking(3.5)
                .textCase(.uppercase)
                .foregroundStyle(Theme.Editorial.onSurface)
                .padding(.bottom, 14)

            heroBlock
                .padding(.bottom, 8)

            Text(curatedLine)
                .font(Theme.Editorial.Typography.caps(9, weight: .semibold))
                .tracking(2)
                .textCase(.uppercase)
                .foregroundStyle(Theme.Editorial.onSurfaceMuted)
                .padding(.bottom, 22)

            DayRail(selection: $selectedDay)
                .padding(.bottom, 18)

            content

            if let localError {
                Text(localError)
                    .font(Theme.Editorial.Typography.caps(9, weight: .semibold))
                    .tracking(1)
                    .foregroundStyle(Theme.Editorial.onSurfaceMuted)
                    .padding(.top, 8)
            }

            Spacer(minLength: 80)
        }
        .padding(.horizontal, Theme.Editorial.Spacing.pad)
        .padding(.top, Theme.Editorial.Spacing.topInset)
    }

    private var nightLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            Masthead(
                wordmark: "MEALS",
                trailing: RomanNumeral.eveningString(from: Date()),
                onTapWordmark: onTapWordmark
            )
            .padding(.bottom, 24)

            Text(sectionLabel)
                .font(Theme.Editorial.Typography.capsBold(10))
                .tracking(3.5)
                .textCase(.uppercase)
                .foregroundStyle(Theme.Editorial.onSurface)
                .padding(.bottom, 14)

            VStack(alignment: .leading, spacing: 0) {
                Text("\(mealCountWord) meals,")
                    .font(Theme.Editorial.Typography.displaySmall())
                Text("well done.")
                    .font(Theme.Editorial.Typography.displaySmall())
                    .italic()
            }
            .kerning(-0.8)
            .lineSpacing(-4)
            .foregroundStyle(Theme.Editorial.onSurface)
            .padding(.bottom, 8)

            Text("A FULL PLATE · EVENING RECAP")
                .font(Theme.Editorial.Typography.caps(9, weight: .semibold))
                .tracking(2)
                .textCase(.uppercase)
                .foregroundStyle(Theme.Editorial.onSurfaceMuted)
                .padding(.bottom, 22)

            DailyTotalsRow(
                proteinGrams: nightProteinTotal,
                calories: nightCalorieTotal,
                mealsCompleted: meals.count,
                mealsTotal: meals.count == 0 ? 3 : meals.count
            )
            .padding(.bottom, 22)

            VStack(spacing: 0) {
                if meals.isEmpty {
                    emptyState
                } else {
                    ForEach(meals, id: \.id) { meal in
                        MealRowNight(
                            time: timeLabel(for: meal),
                            name: meal.name,
                            proteinGrams: Int(meal.proteinGrams),
                            calories: Int(meal.caloriesTotal),
                            onTap: {
                                HapticManager.light()
                                expandedMealId = expandedMealId == meal.id ? nil : meal.id
                            }
                        )
                        if expandedMealId == meal.id {
                            mealExpansion(meal).padding(.bottom, 12)
                        }
                    }
                }
            }

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 14) {
                HairlineDivider()
                HStack(alignment: .center, spacing: 10) {
                    MiraWaveform(state: .idle, size: .compact)
                    Text(nightRecapMessage)
                        .font(Theme.Editorial.Typography.miraBody())
                        .foregroundStyle(Theme.Editorial.onSurface)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.top, 16)
            .padding(.bottom, 80)
        }
        .padding(.horizontal, Theme.Editorial.Spacing.pad)
        .padding(.top, Theme.Editorial.Spacing.topInset)
    }

    // MARK: - Night totals + recap

    private var nightProteinTotal: Int {
        Int(meals.reduce(0.0) { $0 + $1.proteinGrams }.rounded())
    }

    private var nightCalorieTotal: Int {
        Int(meals.reduce(0.0) { $0 + $1.caloriesTotal }.rounded())
    }

    private var nightRecapMessage: String {
        if meals.isEmpty {
            return "Tomorrow's plan is ready when you are."
        }
        if let target = profile?.proteinTargetGrams,
           Double(target) > 0,
           Double(nightProteinTotal) >= Double(target) * 0.95 {
            return "A complete day. Tomorrow's plan is ready when you are."
        }
        return "Closing well. Tomorrow we go again, kindly."
    }

    // MARK: - Hero

    private var heroBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                Text(mealCountWord)
                    .font(Theme.Editorial.Typography.displaySmall())
                    .italic()
                Text(" meals,")
                    .font(Theme.Editorial.Typography.displaySmall())
            }
            Text(modeTagline)
                .font(Theme.Editorial.Typography.displaySmall())
        }
        .kerning(-0.8)
        .lineSpacing(-4)
        .foregroundStyle(Theme.Editorial.onSurface)
    }

    private var mealCountWord: String {
        let count = meals.count
        if count > 0 { return EnglishNumber.word(from: count).capitalized }
        return "Three"
    }

    private var modeTagline: String {
        switch profile?.productMode ?? .everyday {
        case .everyday:            return "balanced and clear."
        case .sensitiveStomach:    return "gentle on the gut."
        case .musclePreservation:  return "high in protein."
        case .trainingPerformance: return "fueled for the lift."
        case .maintenanceTaper:    return "steady through the taper."
        }
    }

    // MARK: - Caps

    private var sectionLabel: String {
        let day = cycleDayNumber
        let mark = "N° \(RomanNumeral.string(from: day))"
        let isToday = Calendar.current.isDateInToday(selectedDate)
        return isToday ? "\(mark) · TODAY" : "\(mark) · \(selectedDay.label)"
    }

    private var cycleDayNumber: Int {
        let start = medication?.startDate ?? profile?.createdAt
        guard let start else { return 1 }
        let days = Calendar.current.dateComponents([.day], from: start, to: .now).day ?? 0
        return max(1, days + 1)
    }

    private var currentWeekNumber: String {
        let week = Calendar.current.component(.weekOfYear, from: .now)
        return String(format: "%02d", week)
    }

    private var curatedLine: String {
        "MIRA · CURATED FOR DAY \(EnglishNumber.word(from: cycleDayNumber).uppercased())"
    }

    // MARK: - Meal list

    @ViewBuilder
    private var content: some View {
        if let job = inFlightJob {
            weeklyInFlightState(job: job)
        } else if meals.isEmpty {
            emptyState
        } else {
            VStack(spacing: 0) {
                ForEach(meals, id: \.id) { meal in
                    MealRow(
                        time: timeLabel(for: meal),
                        name: meal.name,
                        proteinGrams: Int(meal.proteinGrams),
                        calories: Int(meal.caloriesTotal),
                        prepMinutes: meal.prepTimeMinutes,
                        onTap: {
                            HapticManager.light()
                            expandedMealId = expandedMealId == meal.id ? nil : meal.id
                        }
                    )

                    if expandedMealId == meal.id {
                        mealExpansion(meal)
                            .padding(.bottom, 12)
                    }
                }
            }
        }
    }

    private func sortKey(for meal: Meal) -> Int {
        switch meal.mealType {
        case .breakfast:   0
        case .preWorkout:  1
        case .lunch:       2
        case .snack:       3
        case .postWorkout: 4
        case .dinner:      5
        }
    }

    private func timeLabel(for meal: Meal) -> String {
        let type = meal.mealType.rawValue.uppercased()
        switch meal.mealType {
        case .breakfast:   return "07 : 30 · \(type)"
        case .lunch:       return "13 : 00 · \(type)"
        case .dinner:      return "19 : 00 · \(type)"
        case .snack:       return "15 : 00 · \(type)"
        case .preWorkout:  return "06 : 00 · \(type)"
        case .postWorkout: return "20 : 30 · \(type)"
        }
    }

    private func mealExpansion(_ meal: Meal) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if !meal.ingredients.isEmpty {
                Text("INGREDIENTS")
                    .font(Theme.Editorial.Typography.capsBold(9))
                    .tracking(2)
                    .foregroundStyle(Theme.Editorial.onSurfaceMuted)
                Text(meal.ingredients.joined(separator: ", "))
                    .font(Theme.Editorial.Typography.body())
                    .foregroundStyle(Theme.Editorial.onSurfaceMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let instructions = meal.cookingInstructions, !instructions.isEmpty {
                Text("INSTRUCTIONS")
                    .font(Theme.Editorial.Typography.capsBold(9))
                    .tracking(2)
                    .foregroundStyle(Theme.Editorial.onSurfaceMuted)
                    .padding(.top, 4)
                Text(instructions)
                    .font(Theme.Editorial.Typography.body())
                    .foregroundStyle(Theme.Editorial.onSurfaceMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, 4)
    }

    // MARK: - States

    private func weeklyInFlightState(job: MealGenerationJob) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                MiraWaveform(state: .thinking, size: .inline)
                    .frame(height: 28)
                Text("MIRA IS CURATING YOUR WEEK")
                    .font(Theme.Editorial.Typography.capsBold(10))
                    .tracking(2.2)
                    .foregroundStyle(Theme.Editorial.onSurface)
            }

            Text("DAY \(EnglishNumber.word(from: job.daysCompleted).uppercased()) OF \(EnglishNumber.word(from: job.totalDays).uppercased()) READY")
                .font(Theme.Editorial.Typography.caps(9, weight: .semibold))
                .tracking(1.6)
                .foregroundStyle(Theme.Editorial.onSurfaceMuted)
        }
        .padding(.vertical, 24)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(emptyStateLabel)
                .font(Theme.Editorial.Typography.capsBold(10))
                .tracking(2.2)
                .foregroundStyle(Theme.Editorial.onSurface)

            if Calendar.current.isDateInToday(selectedDate) ||
               (selectedDate >= Calendar.current.startOfDay(for: .now) && lastJobFailedSelectedDay) {
                Button {
                    regenerateWeek()
                } label: {
                    HStack(spacing: 10) {
                        Text(regenButtonLabel)
                            .font(Theme.Editorial.Typography.capsBold(11))
                            .tracking(2.5)
                            .foregroundStyle(Theme.Editorial.onSurface)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Theme.Editorial.onSurface)
                    }
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(alignment: .top) { HairlineDivider() }
                    .overlay(alignment: .bottom) { HairlineDivider() }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(regenButtonLabel)
            } else {
                Text("MIRA CURATES UPCOMING DAYS")
                    .font(Theme.Editorial.Typography.caps(9, weight: .semibold))
                    .tracking(1.6)
                    .foregroundStyle(Theme.Editorial.onSurfaceMuted)
            }
        }
        .padding(.vertical, 24)
    }

    private var emptyStateLabel: String {
        if lastJobFailedSelectedDay {
            return "MIRA COULDN'T REACH THIS DAY"
        }
        return "NO PLAN FOR THIS DAY YET"
    }

    private var regenButtonLabel: String {
        if lastJobFailedSelectedDay {
            return "RETRY THIS WEEK"
        }
        return "GENERATE THIS WEEK"
    }

    // MARK: - Generate

    private func regenerateWeek() {
        guard let profile else { return }
        localError = nil

        let isPro = subscriptionManager.tier == .pro
        let orchestrator = WeeklyMealPlanOrchestrator()
        let outcome = orchestrator.startWeekly(
            profile: profile,
            giTriggers: fetchGITriggers(),
            pantryItems: fetchPantryItems(),
            startDate: .now,
            days: 7,
            trigger: .manual,
            isPro: isPro,
            context: modelContext
        )

        if case .rejected(let reason) = outcome {
            switch reason {
            case .featureFlagDisabled:
                localError = "WEEKLY PLANS ARE PAUSED. PLEASE CHECK BACK SOON."
            case .quotaExhausted:
                localError = isPro
                    ? "MIRA IS CATCHING UP, TRY AGAIN IN A MOMENT."
                    : "FREE WEEKLY REGEN AVAILABLE ONCE PER DAY. UPGRADE FOR UNLIMITED."
            case .alreadyInFlight:
                localError = "MIRA IS ALREADY CURATING THIS WEEK."
            }
        }
    }

    private func fetchGITriggers() -> [String] {
        let descriptor = FetchDescriptor<GIToleranceRecord>()
        let records = (try? modelContext.fetch(descriptor)) ?? []
        return records.map(\.foodName)
    }

    private func fetchPantryItems() -> [PantryItem] {
        let descriptor = FetchDescriptor<PantryItem>()
        return (try? modelContext.fetch(descriptor)) ?? []
    }
}
