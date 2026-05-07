import SwiftData
import SwiftUI

/// Editorial Meals tab. Masthead → cycle marker → hero → day rail →
/// meal rows. Tap a row to expand its ingredients/instructions.
struct MealsView: View {
    let mode: MAMode
    let onTapWordmark: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Environment(SubscriptionManager.self) private var subscriptionManager
    @Query private var profiles: [UserProfile]
    @Query(sort: \MealPlan.date, order: .reverse) private var plans: [MealPlan]
    @Query(sort: \MedicationProfile.startDate, order: .reverse) private var medications: [MedicationProfile]
    @Query private var jobs: [MealGenerationJob]

    @State private var selectedDay: Weekday = Weekday.from(date: .now)
    /// Week relative to "this week" (the week that contains today). 0 is
    /// current; negative is past, positive is future. Bounded by
    /// `earliestWeekOffset` (so users can't navigate before they have any
    /// data) and `Self.maxFutureWeeks` (so idle scrolling doesn't trigger
    /// six months of speculative meal generation).
    @State private var weekOffset: Int = 0
    @State private var expandedMealId: String? = nil
    @State private var localError: String? = nil
    @State private var groceryFeedback: String? = nil
    @State private var swappingMeal: Meal? = nil

    /// Forward navigation cap. Four weeks is enough for "show me next month
    /// roughly" without inviting the user to plan a quarter ahead — meal
    /// generation runs at signup + per-week regen + backfill, not as a
    /// rolling 90-day plan, and removing this cap would let an idle swipe
    /// gesture trigger weeks of unused Bedrock spend.
    private static let maxFutureWeeks = 4

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

    /// Earliest plan we've ever generated, used to bound backward
    /// navigation. `plans` is reverse-chrono so `.last` is the oldest;
    /// reading `.last` on a sorted Array is O(1) so this stays cheap on
    /// every render. No separate query needed.
    private var earliestPlanDate: Date? { plans.last?.date }

    /// Backward bound expressed as a week offset relative to today.
    /// Returns 0 when the user has no plans yet (lock to current week);
    /// otherwise the negative offset to the week containing the earliest
    /// plan.
    private var earliestWeekOffset: Int {
        guard let earliest = earliestPlanDate else { return 0 }
        let cal = Calendar.current
        let earliestWeekStart = sundayOfWeek(containing: cal.startOfDay(for: earliest))
        let thisWeekStart = sundayOfWeek(containing: cal.startOfDay(for: .now))
        let dayDiff = cal.dateComponents([.day], from: thisWeekStart, to: earliestWeekStart).day ?? 0
        return min(dayDiff / 7, 0)
    }

    /// Inclusive offsets the user is allowed to navigate to.
    private var weekOffsetRange: ClosedRange<Int> {
        earliestWeekOffset...Self.maxFutureWeeks
    }

    /// Sunday-anchored start of the displayed week.
    private var displayedWeekStart: Date {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let thisWeekSunday = sundayOfWeek(containing: today)
        return cal.date(byAdding: .day, value: weekOffset * 7, to: thisWeekSunday) ?? today
    }

    private var displayedWeekEnd: Date {
        Calendar.current.date(byAdding: .day, value: 6, to: displayedWeekStart) ?? displayedWeekStart
    }

    /// "MAY 5 - 11" when start and end share a month, otherwise "APR 27 - MAY 3".
    /// Hyphen separator (not en/em dash) per the no-em-dash UI rule.
    private var displayedWeekRange: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        let startStr = fmt.string(from: displayedWeekStart).uppercased()
        let cal = Calendar.current
        if cal.isDate(displayedWeekStart, equalTo: displayedWeekEnd, toGranularity: .month) {
            let dayFmt = DateFormatter()
            dayFmt.dateFormat = "d"
            return "\(startStr) - \(dayFmt.string(from: displayedWeekEnd))"
        }
        return "\(startStr) - \(fmt.string(from: displayedWeekEnd).uppercased())"
    }

    private func sundayOfWeek(containing date: Date) -> Date {
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: date) // 1 = Sun ... 7 = Sat
        return cal.date(byAdding: .day, value: -(weekday - 1), to: date) ?? date
    }

    private var selectedDate: Date {
        Calendar.current.date(
            byAdding: .day,
            value: selectedDay.calendarWeekday - 1,
            to: displayedWeekStart
        ) ?? displayedWeekStart
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
        layoutForMode
            .alert(
                "Grocery list",
                isPresented: Binding(
                    get: { groceryFeedback != nil },
                    set: { if !$0 { groceryFeedback = nil } }
                ),
                presenting: groceryFeedback
            ) { _ in
                Button("OK", role: .cancel) { groceryFeedback = nil }
            } message: { text in
                Text(text)
            }
            .sheet(item: $swappingMeal) { meal in
                MealSwapSheet(meal: meal) { swappedTo in
                    recordSwap(meal: meal, swappedTo: swappedTo)
                }
            }
    }

    @ViewBuilder
    private var layoutForMode: some View {
        switch mode {
        case .day:   dayLayout
        case .night: nightLayout
        }
    }

    private var dayLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            Masthead(
                wordmark: "MEALS",
                trailing: dayMastheadTrailing,
                onTapWordmark: onTapWordmark
            )
            .padding(.horizontal, Theme.Editorial.Spacing.pad)
            .padding(.bottom, 24)

            Text(sectionLabel)
                .font(Theme.Editorial.Typography.capsBold(10))
                .tracking(3.5)
                .textCase(.uppercase)
                .foregroundStyle(Theme.Editorial.onSurface)
                .padding(.horizontal, Theme.Editorial.Spacing.pad)
                .padding(.bottom, 14)

            heroBlock
                .padding(.horizontal, Theme.Editorial.Spacing.pad)
                .padding(.bottom, 8)

            Text(curatedLine)
                .font(Theme.Editorial.Typography.caps(9, weight: .semibold))
                .tracking(2)
                .textCase(.uppercase)
                .foregroundStyle(Theme.Editorial.onSurfaceMuted)
                .padding(.horizontal, Theme.Editorial.Spacing.pad)
                .padding(.bottom, 22)

            weekNavigationHeader
                .padding(.horizontal, Theme.Editorial.Spacing.pad)

            // Paged week content. TabView with .page style gives the
            // horizontal swipe + edge resistance + accessibility for
            // free, and avoids the dragGesture-vs-vertical-scroll
            // conflict the meal list would otherwise produce.
            TabView(selection: $weekOffset) {
                ForEach(weekOffsetRange, id: \.self) { offset in
                    weekPage(for: offset)
                        .tag(offset)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(maxWidth: .infinity)
            .frame(minHeight: 360)
            .animation(.easeInOut(duration: 0.18), value: weekOffset)

            if let localError {
                Text(localError)
                    .font(Theme.Editorial.Typography.caps(9, weight: .semibold))
                    .tracking(1)
                    .foregroundStyle(Theme.Editorial.onSurfaceMuted)
                    .padding(.horizontal, Theme.Editorial.Spacing.pad)
                    .padding(.top, 8)
            }

            Spacer(minLength: 80)
        }
        .padding(.top, Theme.Editorial.Spacing.topInset)
    }

    /// Day-mode masthead trailing. Stays "WEEK · NN" of today (the
    /// masthead is a static "now" anchor); the displayed week's date
    /// range lives in `weekNavigationHeader`.
    private var dayMastheadTrailing: String {
        "WEEK · \(currentWeekNumber)"
    }

    /// Chevron-flanked week label above the day rail. Drives `weekOffset`
    /// state, which both the TabView selection and the data computeds
    /// observe.
    private var weekNavigationHeader: some View {
        HStack(spacing: 12) {
            chevronButton(
                systemName: "chevron.left",
                accessibility: "Previous week",
                disabled: weekOffset <= earliestWeekOffset
            ) {
                if weekOffset > earliestWeekOffset {
                    weekOffset -= 1
                }
            }

            Spacer(minLength: 4)

            VStack(spacing: 2) {
                Text(displayedWeekHeadline)
                    .font(Theme.Editorial.Typography.capsBold(10))
                    .tracking(2.2)
                    .foregroundStyle(Theme.Editorial.onSurface)
                Text(displayedWeekRange)
                    .font(Theme.Editorial.Typography.caps(9, weight: .medium))
                    .tracking(1.8)
                    .foregroundStyle(Theme.Editorial.onSurfaceMuted)
            }

            Spacer(minLength: 4)

            chevronButton(
                systemName: "chevron.right",
                accessibility: "Next week",
                disabled: weekOffset >= Self.maxFutureWeeks
            ) {
                if weekOffset < Self.maxFutureWeeks {
                    weekOffset += 1
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 10)
    }

    private func chevronButton(
        systemName: String,
        accessibility: String,
        disabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            HapticManager.selection()
            action()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(
                    disabled
                        ? Theme.Editorial.onSurface.opacity(0.25)
                        : Theme.Editorial.onSurface
                )
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .accessibilityLabel(accessibility)
    }

    private var displayedWeekHeadline: String {
        switch weekOffset {
        case 0:  return "THIS WEEK"
        case -1: return "LAST WEEK"
        case 1:  return "NEXT WEEK"
        case let n where n < 0: return "\(-n) WEEKS AGO"
        default: return "IN \(weekOffset) WEEKS"
        }
    }

    /// One paged week's content. DayRail + meal list / empty state for
    /// the given `offset`. Adjacent pages render eagerly (TabView page
    /// style is non-lazy), so each page reads from the shared @Query
    /// state via `meals(for:)` and stays cheap.
    @ViewBuilder
    private func weekPage(for offset: Int) -> some View {
        VStack(spacing: 0) {
            DayRail(selection: $selectedDay)
                .padding(.bottom, 18)

            if offset == weekOffset {
                content

                if weekHasAnyPlans {
                    weekGroceryButton
                        .padding(.top, 18)
                }
            } else {
                // Off-screen pages: render a placeholder of the same
                // approximate height so the TabView's page semantics
                // don't snap when the user partially swipes. Cheap to
                // render; never visible at rest.
                Color.clear.frame(height: 200)
            }
        }
        .padding(.horizontal, Theme.Editorial.Spacing.pad)
    }

    /// True when at least one active MealPlan exists in the displayed week.
    /// Gates the "PLAN WEEK'S GROCERIES" CTA so it doesn't appear on a
    /// week the user hasn't generated yet.
    private var weekHasAnyPlans: Bool {
        let cal = Calendar.current
        let start = displayedWeekStart
        return plans.contains { plan in
            plan.isActive
                && plan.date >= start
                && plan.date <= cal.date(byAdding: .day, value: 6, to: start) ?? start
        }
    }

    private var weekGroceryButton: some View {
        Button {
            HapticManager.light()
            addWeekIngredientsToGrocery()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "cart.badge.plus")
                    .font(.system(size: 12, weight: .semibold))
                Text("PLAN WEEK'S GROCERIES")
                    .font(Theme.Editorial.Typography.capsBold(11))
                    .tracking(2.5)
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 11, weight: .bold))
            }
            .foregroundStyle(Theme.Editorial.onSurface)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .overlay(alignment: .top) { HairlineDivider() }
            .overlay(alignment: .bottom) { HairlineDivider() }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add this week's ingredients to grocery list")
    }

    private var nightLayout: some View {
        // Night mode is the "tonight's recap" framing — always reads
        // today's plan regardless of where the user navigated to in
        // day mode. weekOffset stays as the user left it so day mode
        // resumes where they were on next morning's auto-flip.
        let tonightMeals = todaysActiveMeals
        let proteinTotal = Int(tonightMeals.reduce(0.0) { $0 + $1.proteinGrams }.rounded())
        let calorieTotal = Int(tonightMeals.reduce(0.0) { $0 + $1.caloriesTotal }.rounded())
        let countWord = tonightMeals.isEmpty
            ? "Three"
            : EnglishNumber.word(from: tonightMeals.count).capitalized

        return VStack(alignment: .leading, spacing: 0) {
            Masthead(
                wordmark: "MEALS",
                trailing: EditorialDate.eveningString(from: Date(), style: appState.numberStyle),
                onTapWordmark: onTapWordmark
            )
            .padding(.bottom, 24)

            Text(tonightSectionLabel)
                .font(Theme.Editorial.Typography.capsBold(10))
                .tracking(3.5)
                .textCase(.uppercase)
                .foregroundStyle(Theme.Editorial.onSurface)
                .padding(.bottom, 14)

            VStack(alignment: .leading, spacing: 0) {
                Text("\(countWord) meals,")
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
                proteinGrams: proteinTotal,
                calories: calorieTotal,
                mealsCompleted: tonightMeals.count,
                mealsTotal: tonightMeals.count == 0 ? 3 : tonightMeals.count
            )
            .padding(.bottom, 22)

            VStack(spacing: 0) {
                if tonightMeals.isEmpty {
                    emptyState
                } else {
                    ForEach(tonightMeals, id: \.id) { meal in
                        MealRowNight(
                            time: timeLabel(for: meal),
                            name: meal.name,
                            proteinGrams: Int(meal.proteinGrams),
                            calories: Int(meal.caloriesTotal),
                            adherence: meal.adherenceState,
                            onTap: {
                                HapticManager.light()
                                expandedMealId = expandedMealId == meal.id ? nil : meal.id
                            }
                        )
                        .contextMenu { adherenceMenu(for: meal) }
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

    /// Today's active plan, used by the night layout. Bypasses
    /// `weekOffset` because night mode is the "tonight's recap" framing —
    /// it must show today regardless of where the user navigated to in
    /// day mode earlier.
    private var todaysActiveMeals: [Meal] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let plan = plans.first { cal.isDate($0.date, inSameDayAs: today) && $0.isActive }
        return (plan?.meals ?? []).sorted { sortKey(for: $0) < sortKey(for: $1) }
    }

    /// Section label for the night layout — "N° NN · TONIGHT".
    private var tonightSectionLabel: String {
        let mark = EditorialDate.ordinal(cycleDayNumber, style: appState.numberStyle)
        return "\(mark) · TONIGHT"
    }

    private var nightRecapMessage: String {
        let tonightMeals = todaysActiveMeals
        if tonightMeals.isEmpty {
            return "Tomorrow's plan is ready when you are."
        }
        let proteinTotal = tonightMeals.reduce(0.0) { $0 + $1.proteinGrams }
        if let target = profile?.proteinTargetGrams,
           Double(target) > 0,
           proteinTotal >= Double(target) * 0.95 {
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
        let mark = EditorialDate.ordinal(cycleDayNumber, style: appState.numberStyle)
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
        "MIRA · CURATED FOR DAY \(EditorialDate.dayWord(cycleDayNumber, style: appState.numberStyle))"
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
                        adherence: meal.adherenceState,
                        onTap: {
                            HapticManager.light()
                            expandedMealId = expandedMealId == meal.id ? nil : meal.id
                        }
                    )
                    .contextMenu { adherenceMenu(for: meal) }

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

            HStack(spacing: 10) {
                logMealButton(for: meal)
                addToGroceryButton(for: meal)
            }
            .padding(.top, 8)
        }
        .padding(.top, 4)
    }

    private func addToGroceryButton(for meal: Meal) -> some View {
        Button {
            HapticManager.light()
            addIngredientsToGrocery(meal.ingredients)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "cart.badge.plus")
                    .font(.system(size: 11, weight: .semibold))
                Text("TO GROCERY")
                    .font(Theme.Editorial.Typography.capsBold(10))
                    .tracking(2.0)
            }
            .foregroundStyle(Theme.Editorial.onSurface)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Theme.Editorial.hairline, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(meal.ingredients.isEmpty)
        .accessibilityLabel("Add this meal's ingredients to grocery list")
    }

    private func logMealButton(for meal: Meal) -> some View {
        Button {
            HapticManager.success()
            MealLogger.log(
                name: meal.name,
                proteinGrams: meal.proteinGrams,
                caloriesConsumed: meal.caloriesTotal,
                fiberGrams: meal.fiberGrams,
                sourceMeal: meal,
                in: modelContext
            )
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12, weight: .semibold))
                Text("LOG THIS MEAL")
                    .font(Theme.Editorial.Typography.capsBold(10))
                    .tracking(2.0)
            }
            .foregroundStyle(Theme.Editorial.onSurface)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Theme.Editorial.hairline, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Log this meal without a photo")
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

            Text("DAY \(EditorialDate.dayWord(job.daysCompleted, style: appState.numberStyle)) OF \(EditorialDate.dayWord(job.totalDays, style: appState.numberStyle)) READY")
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

            if showsRegenerateButton {
                Button {
                    regenerateWeek(startDate: displayedWeekStart)
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
                Text(pastWeekHelperLine)
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
        if weekOffset == 0 {
            return "NO PLAN FOR THIS DAY YET"
        }
        if weekOffset > 0 {
            return "NO PLAN FOR THIS WEEK YET"
        }
        return "NO PLAN ON FILE FOR THIS WEEK"
    }

    /// Regenerate / Generate button is offered for the current week and
    /// any future week the user might want to plan. Past weeks don't get
    /// a button because the orchestrator would happily generate a "plan"
    /// dated to last month, which is meaningless (you can't eat the past)
    /// and would silently consume a weekly-gen quota slot.
    private var showsRegenerateButton: Bool {
        weekOffset >= 0
    }

    private var pastWeekHelperLine: String {
        "MIRA ONLY PLANS FROM THIS WEEK FORWARD"
    }

    private var regenButtonLabel: String {
        if lastJobFailedSelectedDay {
            return "RETRY THIS WEEK"
        }
        if weekOffset == 0 {
            return "GENERATE THIS WEEK"
        }
        if weekOffset == 1 {
            return "PLAN NEXT WEEK"
        }
        return "PLAN THIS WEEK"
    }

    // MARK: - Generate

    /// Kick off a 7-day generation anchored at `startDate`. Defaults to
    /// today (the original signature) so the dashboard / signup flow keeps
    /// working unchanged; the empty-state button now passes the displayed
    /// week's Sunday so navigating to next month and tapping "PLAN NEXT
    /// WEEK" plans that specific week, not always the current one.
    private func regenerateWeek(startDate: Date = .now) {
        guard let profile else { return }
        localError = nil

        let isPro = subscriptionManager.tier == .pro
        let orchestrator = WeeklyMealPlanOrchestrator()
        let outcome = orchestrator.startWeekly(
            profile: profile,
            giTriggers: fetchGITriggers(),
            pantryItems: fetchPantryItems(),
            startDate: startDate,
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

    // MARK: - Grocery wiring

    /// Single-meal "ADD INGREDIENTS TO GROCERY". Aggregates the ingredient
    /// list onto the user's grocery list via the shared GroceryAdder, then
    /// surfaces a result alert. Reuses the same dedup + categorize as
    /// SavedRecipeDetailView and Mira's chat tool.
    private func addIngredientsToGrocery(_ items: [String]) {
        guard !items.isEmpty else { return }
        let result = GroceryAdder.add(items, in: modelContext)
        do {
            try modelContext.save()
        } catch {
            groceryFeedback = "Couldn't save: \(error.localizedDescription)"
            return
        }
        HapticManager.success()
        groceryFeedback = formatGroceryFeedback(result)
    }

    /// Cross-week aggregation. Pulls every active MealPlan in the displayed
    /// week, flattens ingredients, and pipes the whole batch through
    /// GroceryAdder so dedup runs once across the week instead of once
    /// per meal. The reverse order matters: Sunday's repeats are skipped
    /// against Monday's instead of the user seeing them twice.
    private func addWeekIngredientsToGrocery() {
        let cal = Calendar.current
        let start = displayedWeekStart
        let end = cal.date(byAdding: .day, value: 6, to: start) ?? start
        let weekPlans = plans
            .filter { $0.isActive && $0.date >= start && $0.date <= end }
            .sorted { $0.date < $1.date }

        let allIngredients = weekPlans.flatMap { $0.meals.flatMap(\.ingredients) }
        guard !allIngredients.isEmpty else {
            groceryFeedback = "No meals planned this week yet."
            return
        }
        let result = GroceryAdder.add(allIngredients, in: modelContext)
        do {
            try modelContext.save()
        } catch {
            groceryFeedback = "Couldn't save: \(error.localizedDescription)"
            return
        }
        HapticManager.success()
        groceryFeedback = formatGroceryFeedback(result)
    }

    private func formatGroceryFeedback(_ result: GroceryAdder.Result) -> String {
        if result.added.isEmpty && !result.skipped.isEmpty {
            return "Already on your list."
        }
        if result.skipped.isEmpty {
            let n = result.added.count
            return "Added \(n) ingredient\(n == 1 ? "" : "s") to your grocery list."
        }
        return "Added \(result.added.count). \(result.skipped.count) already on your list."
    }

    // MARK: - Adherence (Task 4)

    /// Context-menu builder for a meal-plan row. Surfaces the four
    /// adherence affordances (Eaten / Skipped / Swap for / Open) that
    /// previously had no UI: row tap was already overloaded for the
    /// expansion toggle, so the new state lives behind a long-press
    /// (.contextMenu) which VoiceOver knows about as the iOS-standard
    /// hidden affordance. Long-press alone would be invisible to
    /// screen readers.
    @ViewBuilder
    private func adherenceMenu(for meal: Meal) -> some View {
        switch meal.adherenceState {
        case .open:
            Button {
                markEaten(meal)
            } label: {
                Label("Mark as eaten", systemImage: "checkmark.circle")
            }
            Button {
                markSkipped(meal)
            } label: {
                Label("Skipped", systemImage: "slash.circle")
            }
            Button {
                swappingMeal = meal
            } label: {
                Label("Swap for...", systemImage: "arrow.triangle.swap")
            }
        case .eaten:
            Button(role: .destructive) {
                clearAdherence(meal)
            } label: {
                Label("Undo log", systemImage: "arrow.uturn.backward")
            }
        case .skipped:
            Button {
                markEaten(meal)
            } label: {
                Label("Actually, I ate it", systemImage: "checkmark.circle")
            }
            Button(role: .destructive) {
                clearAdherence(meal)
            } label: {
                Label("Undo skip", systemImage: "arrow.uturn.backward")
            }
        case .swapped:
            Button {
                swappingMeal = meal
            } label: {
                Label("Edit swap", systemImage: "pencil")
            }
            Button(role: .destructive) {
                clearAdherence(meal)
            } label: {
                Label("Undo swap", systemImage: "arrow.uturn.backward")
            }
        }
    }

    private func markEaten(_ meal: Meal) {
        HapticManager.success()
        MealLogger.log(
            name: meal.name,
            proteinGrams: meal.proteinGrams,
            caloriesConsumed: meal.caloriesTotal,
            fiberGrams: meal.fiberGrams,
            sourceMeal: meal,
            in: modelContext
        )
    }

    private func markSkipped(_ meal: Meal) {
        HapticManager.light()
        meal.consumedAt = nil
        meal.swappedTo = nil
        meal.swappedAt = nil
        meal.skippedAt = .now
        try? modelContext.save()
    }

    private func clearAdherence(_ meal: Meal) {
        HapticManager.light()
        // If this meal had a NutritionLog stamped via "Mark as eaten",
        // delete that log too so today's totals stay honest. Free-form
        // logs (NutritionLog with sourceMealId == nil) are preserved
        // since they came from a different surface.
        let mealId = meal.id
        let descriptor = FetchDescriptor<NutritionLog>(
            predicate: #Predicate { $0.sourceMealId == mealId }
        )
        if let logs = try? modelContext.fetch(descriptor) {
            for log in logs {
                modelContext.delete(log)
            }
        }
        meal.consumedAt = nil
        meal.skippedAt = nil
        meal.swappedTo = nil
        meal.swappedAt = nil
        try? modelContext.save()
    }

    private func recordSwap(meal: Meal, swappedTo name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        HapticManager.light()
        // The swap is a separate signal from "ate this." We don't
        // automatically log a NutritionLog because we don't have macros
        // for the swap target — the user gets a separate "Ate something
        // else" sheet for that case. Here we just record what they ate
        // and when, for Task 5's adherence summary.
        meal.consumedAt = nil
        meal.skippedAt = nil
        meal.swappedTo = trimmed
        meal.swappedAt = .now
        try? modelContext.save()
    }
}

// MARK: - Swap sheet

/// Quick text-entry sheet that captures what the user actually ate
/// instead of the planned meal. Free-form name only; macros come from
/// MealLogger if the user separately taps "Ate something else" on a
/// surface that has macros (Mira chat, dashboard rec card, scan).
struct MealSwapSheet: View {
    let meal: Meal
    let onSubmit: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text("Planned: \(meal.name)")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)

                Text("What did you eat instead?")
                    .font(.system(size: 22, weight: .regular, design: .serif))

                TextField("e.g., Chipotle chicken bowl", text: $draft)
                    .focused($focused)
                    .textInputAutocapitalization(.sentences)
                    .submitLabel(.done)
                    .onSubmit(submit)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(.tertiary, lineWidth: 0.5)
                    )

                Spacer()
            }
            .padding(20)
            .navigationTitle("Swap meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: submit)
                        .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                draft = meal.swappedTo ?? ""
                focused = true
            }
        }
    }

    private func submit() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onSubmit(trimmed)
        dismiss()
    }
}
