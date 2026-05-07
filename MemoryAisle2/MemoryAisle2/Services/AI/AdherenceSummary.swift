import Foundation
import SwiftData

/// Pure, testable summary of how the user has actually eaten over the
/// trailing N days. Built from `Meal.consumedAt / skippedAt / swappedTo /
/// swappedAt` (Task 4 schema) and the user's protein target. No string
/// rendering happens here — `AdherenceContextFormatter` handles the
/// prompt-side text — so this struct is unit-testable without touching
/// any natural-language layer.
///
/// Used by `MealGenerator` (gated on `FeatureFlags.adherenceContext`) to
/// append a "what the user actually ate last week" fragment to the
/// meal-plan prompt so the next generation adapts to their patterns.
struct AdherenceSummary: Equatable, Sendable {

    /// One temporally-ordered swap entry. Raw — no pattern inference here;
    /// Mira gets the list and finds patterns at the model layer (regex-
    /// matching three swap entries to detect "user prefers takeout on
    /// Tuesdays" is a coin flip, and the model is much better at it).
    struct SwapEntry: Equatable, Sendable {
        let date: Date
        let mealType: MealType
        let plannedName: String
        let swappedTo: String
    }

    /// Days where consumed protein hit at least 90% of target. Counts only
    /// days that had at least one logged or swapped meal — fully untouched
    /// days don't count as a "miss" because we can't tell whether the user
    /// actually skipped or just didn't log.
    let proteinHitDays: Int
    /// Days that had logging activity but didn't reach the protein
    /// threshold. Distinct from `untouchedDays` for the same reason.
    let proteinMissDays: Int
    /// Days in the window with no signal at all (no consumedAt, no
    /// skippedAt, no swappedAt, no NutritionLog). Reported separately so
    /// the prompt can frame this as "no data" rather than "user failed."
    let untouchedDays: Int
    /// Per-meal-type skip rate over the window: 0.0 to 1.0. nil entries
    /// mean no planned meals of that type existed in the window.
    let skipRateByType: [MealType: Double]
    /// Per-meal-type adherence (consumed / planned), 0.0 to 1.0.
    let adherenceByType: [MealType: Double]
    /// Recent swap log, oldest → newest, capped at 10 entries.
    let recentSwaps: [SwapEntry]
    /// Total span the summary covers (typically 7).
    let windowDays: Int

    /// True when the user has so little adherence signal that feeding the
    /// summary into the prompt would just look like noise. Caller should
    /// skip the adherence-context fragment in this case rather than send
    /// "user has 0/0/0 adherence" which Mira reads as a failure signal.
    var isEmpty: Bool {
        proteinHitDays == 0 &&
            proteinMissDays == 0 &&
            recentSwaps.isEmpty &&
            skipRateByType.allSatisfy { $0.value == 0 }
    }

    // MARK: - Build

    /// Builds the summary from raw model data. Pure compute — no SwiftData
    /// fetches, no IO — so it's straightforward to unit-test with fixtures.
    /// Caller is responsible for the @Query that feeds `plans` and `logs`.
    static func build(
        windowDays: Int = 7,
        anchor: Date = .now,
        plans: [MealPlan],
        nutritionLogs: [NutritionLog],
        proteinTargetGrams: Int,
        calendar: Calendar = .current
    ) -> AdherenceSummary {
        let endOfWindow = calendar.startOfDay(for: anchor)
        guard let start = calendar.date(byAdding: .day, value: -windowDays, to: endOfWindow) else {
            return AdherenceSummary(
                proteinHitDays: 0, proteinMissDays: 0, untouchedDays: windowDays,
                skipRateByType: [:], adherenceByType: [:], recentSwaps: [],
                windowDays: windowDays
            )
        }

        let windowPlans = plans.filter { plan in
            plan.isActive && plan.date >= start && plan.date < endOfWindow
        }

        // Per-day totals: planned protein, consumed protein, any signal at all.
        var proteinHit = 0
        var proteinMiss = 0
        var untouched = 0

        // Per-type counters for skip + adherence rates.
        var plannedCountByType: [MealType: Int] = [:]
        var skippedCountByType: [MealType: Int] = [:]
        var consumedCountByType: [MealType: Int] = [:]

        let dayPlans = Dictionary(grouping: windowPlans, by: { calendar.startOfDay(for: $0.date) })

        // Iterate through each day in the window so untouchedDays counts
        // both "no plan generated" and "plan generated but ignored."
        for offset in 0..<windowDays {
            guard let dayStart = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
            let mealsForDay = (dayPlans[dayStart] ?? []).flatMap(\.meals)
            let logsForDay = nutritionLogs.filter { calendar.isDate($0.date, inSameDayAs: dayStart) }

            // Count planned/skipped/consumed by type for the per-type rates.
            for meal in mealsForDay {
                plannedCountByType[meal.mealType, default: 0] += 1
                if meal.skippedAt != nil {
                    skippedCountByType[meal.mealType, default: 0] += 1
                }
                if meal.consumedAt != nil {
                    consumedCountByType[meal.mealType, default: 0] += 1
                }
            }

            // Daily protein totals come from NutritionLog (not Meal.consumedAt
            // directly) because the user might have logged free-form meals
            // outside the plan and they all count toward the target.
            let consumedProtein = logsForDay.reduce(0.0) { $0 + $1.proteinGrams }
            let hasAnySignal =
                !logsForDay.isEmpty
                || mealsForDay.contains { $0.consumedAt != nil || $0.skippedAt != nil || $0.swappedAt != nil }

            if !hasAnySignal {
                untouched += 1
                continue
            }

            if proteinTargetGrams > 0,
               consumedProtein >= Double(proteinTargetGrams) * 0.9 {
                proteinHit += 1
            } else {
                proteinMiss += 1
            }
        }

        // Per-type rates.
        var skipRate: [MealType: Double] = [:]
        var adherenceRate: [MealType: Double] = [:]
        for (type, planned) in plannedCountByType where planned > 0 {
            skipRate[type] = Double(skippedCountByType[type] ?? 0) / Double(planned)
            adherenceRate[type] = Double(consumedCountByType[type] ?? 0) / Double(planned)
        }

        // Swap log (raw, sorted oldest → newest, capped at 10).
        let swaps: [SwapEntry] = windowPlans
            .flatMap(\.meals)
            .compactMap { meal -> SwapEntry? in
                guard let when = meal.swappedAt, let to = meal.swappedTo else { return nil }
                return SwapEntry(
                    date: when,
                    mealType: meal.mealType,
                    plannedName: meal.name,
                    swappedTo: to
                )
            }
            .sorted { $0.date < $1.date }
            .suffix(10)
            .map { $0 }

        return AdherenceSummary(
            proteinHitDays: proteinHit,
            proteinMissDays: proteinMiss,
            untouchedDays: untouched,
            skipRateByType: skipRate,
            adherenceByType: adherenceRate,
            recentSwaps: swaps,
            windowDays: windowDays
        )
    }
}

/// Renders an AdherenceSummary into a prompt fragment. Lives apart from
/// the summary so prompt-language tuning doesn't change computation, and
/// vice versa — both are independently unit-testable.
enum AdherenceContextFormatter {

    /// Formats the trailing summary for the meal-plan system prompt.
    /// Returns an empty string when the summary is empty (no signal yet)
    /// so callers can append unconditionally without "0/0/0 adherence"
    /// noise leaking into the prompt.
    static func format(_ summary: AdherenceSummary) -> String {
        if summary.isEmpty { return "" }

        var lines: [String] = []
        lines.append("\nADHERENCE CONTEXT (last \(summary.windowDays) days):")

        // Days bucket — only mention if there's signal.
        let totalLogged = summary.proteinHitDays + summary.proteinMissDays
        if totalLogged > 0 {
            lines.append("- Protein target hit: \(summary.proteinHitDays) of \(totalLogged) tracked days.")
        }
        if summary.untouchedDays > 0 {
            lines.append("- \(summary.untouchedDays) day(s) had no logging activity (treat as no-data, not as failure).")
        }

        // Per-type skip patterns — only call out elevated skip rates.
        let elevatedSkips = summary.skipRateByType
            .filter { $0.value >= 0.4 }
            .sorted(by: { $0.value > $1.value })
        for (type, rate) in elevatedSkips {
            let pct = Int((rate * 100).rounded())
            lines.append("- Skipped \(pct)% of planned \(type.rawValue.lowercased())s.")
        }

        // Recent swaps — raw entries, let the model find the pattern.
        if !summary.recentSwaps.isEmpty {
            lines.append("- Recent swaps (planned → ate):")
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "EEE"
            for swap in summary.recentSwaps {
                let day = dayFormatter.string(from: swap.date)
                let typeLabel = swap.mealType.rawValue.lowercased()
                lines.append("  • \(day) \(typeLabel): \(swap.plannedName) → \(swap.swappedTo)")
            }
        }

        lines.append(
            "Use this to adapt the next plan: lean into what they ate, away from what they skipped, and respect their swap preferences without assuming a pattern unless the data clearly shows one."
        )

        return lines.joined(separator: "\n")
    }
}
