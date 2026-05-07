import XCTest
@testable import MemoryAisle2

/// Pins the AdherenceSummary computation contract (Task 5). The
/// summary feeds the meal-plan prompt when the adherenceContext flag
/// is on, so a regression in this math would silently change the
/// signal Mira reasons over. Pure compute — no SwiftData fetches in
/// the tests, just hand-built model fixtures.
@MainActor
final class AdherenceSummaryTests: XCTestCase {

    // Anchor every test at a fixed date so day-bucketing math is
    // deterministic across CI machines and timezones.
    private let anchor: Date = {
        var components = DateComponents()
        components.year = 2026
        components.month = 5
        components.day = 7
        components.hour = 12
        return Calendar.current.date(from: components)!
    }()

    private func date(daysBefore offset: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -offset, to: anchor)!
    }

    private func makeMeal(
        type: MealType = .lunch,
        name: String = "Test meal",
        protein: Double = 30,
        consumed: Date? = nil,
        skipped: Date? = nil,
        swappedTo: String? = nil,
        swappedAt: Date? = nil
    ) -> Meal {
        let meal = Meal(
            name: name,
            mealType: type,
            proteinGrams: protein,
            caloriesTotal: 400
        )
        meal.consumedAt = consumed
        meal.skippedAt = skipped
        meal.swappedTo = swappedTo
        meal.swappedAt = swappedAt
        return meal
    }

    private func makePlan(date: Date, meals: [Meal]) -> MealPlan {
        let plan = MealPlan(date: date, productMode: .everyday, meals: meals)
        plan.isActive = true
        return plan
    }

    // MARK: - Empty state

    func test_emptyInputsProduceEmptySummary() {
        let summary = AdherenceSummary.build(
            windowDays: 7,
            anchor: anchor,
            plans: [],
            nutritionLogs: [],
            proteinTargetGrams: 130
        )
        XCTAssertEqual(summary.untouchedDays, 7)
        XCTAssertEqual(summary.proteinHitDays, 0)
        XCTAssertEqual(summary.proteinMissDays, 0)
        XCTAssertTrue(summary.recentSwaps.isEmpty)
        XCTAssertTrue(summary.isEmpty)
    }

    func test_isEmptyShortCircuitsTheFormatter() {
        let summary = AdherenceSummary.build(
            windowDays: 7, anchor: anchor,
            plans: [], nutritionLogs: [],
            proteinTargetGrams: 130
        )
        XCTAssertEqual(AdherenceContextFormatter.format(summary), "")
    }

    // MARK: - Day bucketing

    func test_proteinHitDayCountsAtNinetyPercentOfTarget() {
        // 117g consumed, 130g target → 90% exactly → counts as a hit.
        let log = NutritionLog(
            date: date(daysBefore: 1),
            proteinGrams: 117,
            caloriesConsumed: 1500,
            foodName: "Chicken bowl"
        )
        let summary = AdherenceSummary.build(
            windowDays: 7, anchor: anchor,
            plans: [], nutritionLogs: [log],
            proteinTargetGrams: 130
        )
        XCTAssertEqual(summary.proteinHitDays, 1)
        XCTAssertEqual(summary.proteinMissDays, 0)
    }

    func test_belowNinetyPercentCountsAsMiss() {
        let log = NutritionLog(
            date: date(daysBefore: 2),
            proteinGrams: 100,  // 77% of 130 target
            caloriesConsumed: 1200,
            foodName: "Salad"
        )
        let summary = AdherenceSummary.build(
            windowDays: 7, anchor: anchor,
            plans: [], nutritionLogs: [log],
            proteinTargetGrams: 130
        )
        XCTAssertEqual(summary.proteinHitDays, 0)
        XCTAssertEqual(summary.proteinMissDays, 1)
    }

    func test_dayWithNoSignalCountsAsUntouched_notMiss() {
        // Empty day must NOT count as a protein miss — we don't know
        // whether the user skipped or just didn't log.
        let summary = AdherenceSummary.build(
            windowDays: 7, anchor: anchor,
            plans: [], nutritionLogs: [],
            proteinTargetGrams: 130
        )
        XCTAssertEqual(summary.proteinMissDays, 0)
        XCTAssertEqual(summary.untouchedDays, 7)
    }

    func test_skippedMealCountsAsSignalEvenWithNoLog() {
        // Skipping a planned meal IS a signal; it just doesn't move the
        // protein-hit needle. Day should not be "untouched."
        let meal = makeMeal(skipped: date(daysBefore: 1))
        let plan = makePlan(date: date(daysBefore: 1), meals: [meal])
        let summary = AdherenceSummary.build(
            windowDays: 7, anchor: anchor,
            plans: [plan], nutritionLogs: [],
            proteinTargetGrams: 130
        )
        XCTAssertEqual(summary.untouchedDays, 6) // 7 days − 1 with signal
        XCTAssertEqual(summary.proteinHitDays, 0)
        XCTAssertEqual(summary.proteinMissDays, 1)
    }

    // MARK: - Per-type rates

    func test_skipRateByTypeIsComputedFromPlannedRows() {
        // 2 dinners planned, 1 skipped → 50% skip rate for dinner.
        let dinnerSkipped = makeMeal(type: .dinner, skipped: date(daysBefore: 1))
        let dinnerEaten = makeMeal(type: .dinner, consumed: date(daysBefore: 2))
        let lunchEaten = makeMeal(type: .lunch, consumed: date(daysBefore: 3))

        let plan1 = makePlan(date: date(daysBefore: 1), meals: [dinnerSkipped])
        let plan2 = makePlan(date: date(daysBefore: 2), meals: [dinnerEaten])
        let plan3 = makePlan(date: date(daysBefore: 3), meals: [lunchEaten])

        let summary = AdherenceSummary.build(
            windowDays: 7, anchor: anchor,
            plans: [plan1, plan2, plan3], nutritionLogs: [],
            proteinTargetGrams: 130
        )

        XCTAssertEqual(summary.skipRateByType[.dinner] ?? .nan, 0.5, accuracy: 0.0001)
        XCTAssertEqual(summary.skipRateByType[.lunch] ?? .nan, 0.0, accuracy: 0.0001)
        XCTAssertEqual(summary.adherenceByType[.dinner] ?? .nan, 0.5, accuracy: 0.0001)
        XCTAssertEqual(summary.adherenceByType[.lunch] ?? .nan, 1.0, accuracy: 0.0001)
        XCTAssertNil(summary.skipRateByType[.breakfast])
    }

    // MARK: - Swap log

    func test_swapLogIsTemporallyOrderedAndCappedAtTen() {
        // Build 12 swap entries spread across the window; expect the
        // 10 most-recent in chronological order.
        var meals: [Meal] = []
        for i in (1...12).reversed() {
            let meal = makeMeal(
                type: .dinner,
                name: "Planned \(i)",
                swappedTo: "Ate \(i)",
                swappedAt: date(daysBefore: i)
            )
            meals.append(meal)
        }
        let plan = makePlan(date: date(daysBefore: 1), meals: meals)

        let summary = AdherenceSummary.build(
            windowDays: 14, anchor: anchor,
            plans: [plan], nutritionLogs: [],
            proteinTargetGrams: 130
        )

        XCTAssertEqual(summary.recentSwaps.count, 10)
        // Sorted oldest → newest.
        XCTAssertLessThan(summary.recentSwaps.first!.date, summary.recentSwaps.last!.date)
        // Most recent entry should reflect the swap closest to anchor.
        XCTAssertEqual(summary.recentSwaps.last?.plannedName, "Planned 1")
        XCTAssertEqual(summary.recentSwaps.last?.swappedTo, "Ate 1")
    }

    // MARK: - Formatter

    func test_formatterIncludesTrackedDayLine() {
        let log = NutritionLog(
            date: date(daysBefore: 1),
            proteinGrams: 130,
            caloriesConsumed: 1700,
            foodName: "Chicken"
        )
        let summary = AdherenceSummary.build(
            windowDays: 7, anchor: anchor,
            plans: [], nutritionLogs: [log],
            proteinTargetGrams: 130
        )
        let text = AdherenceContextFormatter.format(summary)
        XCTAssertTrue(text.contains("ADHERENCE CONTEXT"))
        XCTAssertTrue(text.contains("Protein target hit: 1 of 1"))
    }

    func test_formatterCallsOutElevatedSkipRates() {
        // 3 dinners planned, all skipped → 100% skip rate.
        var meals: [Meal] = []
        for i in 1...3 {
            meals.append(makeMeal(type: .dinner, skipped: date(daysBefore: i)))
        }
        let plan = makePlan(date: date(daysBefore: 1), meals: meals)

        let summary = AdherenceSummary.build(
            windowDays: 7, anchor: anchor,
            plans: [plan], nutritionLogs: [],
            proteinTargetGrams: 130
        )
        let text = AdherenceContextFormatter.format(summary)
        XCTAssertTrue(text.contains("Skipped 100% of planned dinners"))
    }

    func test_formatterEmitsRawSwapLogWithoutPatternInference() {
        let meal = makeMeal(
            type: .dinner,
            name: "Salmon bowl",
            swappedTo: "Chipotle",
            swappedAt: date(daysBefore: 2)
        )
        let plan = makePlan(date: date(daysBefore: 2), meals: [meal])
        let summary = AdherenceSummary.build(
            windowDays: 7, anchor: anchor,
            plans: [plan], nutritionLogs: [],
            proteinTargetGrams: 130
        )
        let text = AdherenceContextFormatter.format(summary)
        XCTAssertTrue(text.contains("Salmon bowl → Chipotle"))
        // Pattern inference must NOT happen client-side. Check for the
        // specific inference verbs that would indicate we tried to
        // detect patterns ourselves (rather than letting the model
        // do it). The word "pattern" itself is allowed in the prompt
        // instruction line — it tells Mira not to assume one.
        let lower = text.lowercased()
        XCTAssertFalse(lower.contains("user prefers"))
        XCTAssertFalse(lower.contains("user tends to"))
        XCTAssertFalse(lower.contains("pattern detected"))
        XCTAssertFalse(lower.contains("appears to prefer"))
    }
}
