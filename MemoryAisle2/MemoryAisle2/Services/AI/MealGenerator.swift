import Foundation
import OSLog
import SwiftData

/// Per-day outcome from `generateWeeklyPlan`. `plansByDate` holds successful days;
/// `failures` maps each failed start-of-day Date to the error so the caller can
/// surface a per-day retry without re-running the days that already succeeded.
struct WeeklyPlanResult: Sendable {
    var plansByDate: [Date: MealPlan.ID] = [:]
    var failures: [Date: String] = [:]

    var successCount: Int { plansByDate.count }
    var failureCount: Int { failures.count }
}

@MainActor
final class MealGenerator {
    private let apiClient = MiraAPIClient()
    private let logger = Logger(subsystem: "com.memoryaisle.MealGen", category: "Generator")

    // MARK: - Single day

    /// Generate one day's meal plan via the structured-output Lambda path.
    /// Calls `mode: "meal_plan"` on the Mira endpoint, which forces a
    /// `presentMealPlan` tool_use call and validates the result before
    /// returning. `avoidMealNames` is the cumulative list of meal names
    /// already planned earlier in the week, so Mira varies the protein
    /// source and meal style across the seven days.
    ///
    /// Throws `MiraAPIClient.MealPlanError`; the weekly loop classifies
    /// retry policy from `isRetryable`.
    func generateDailyPlan(
        profile: UserProfile,
        cyclePhase: CyclePhase?,
        giTriggers: [String],
        pantryItems: [PantryItem],
        isTrainingDay: Bool,
        date: Date = .now,
        avoidMealNames: [String] = [],
        context: ModelContext
    ) async throws -> MealPlan {
        let started = Date()
        logger.info("Generating plan for \(date.ISO8601Format(), privacy: .public), avoid=\(avoidMealNames.count, privacy: .public)")

        let anon = MedicationAnonymizer.anonymize(
            profile: profile,
            cyclePhase: cyclePhase,
            symptomState: "unknown",
            proteinConsumed: 0,
            waterConsumed: 0,
            isTrainingDay: isTrainingDay
        )
        let miraContext = MiraAPIClient.MiraContext(
            medicationClass: anon.medicationClass,
            doseTier: anon.doseTier,
            daysSinceDose: anon.daysSinceDose,
            phase: anon.phase,
            symptomState: anon.symptomState,
            mode: anon.productMode,
            proteinTarget: anon.proteinTargetGrams,
            proteinToday: 0,
            waterToday: 0,
            trainingLevel: anon.trainingLevel,
            trainingToday: anon.trainingToday,
            calorieTarget: anon.calorieTarget,
            dietaryRestrictions: anon.dietaryRestrictions
        )

        let pantryNames = pantryItems.prefix(20).map(\.name).filter { !$0.isEmpty }
        let adherence = adherenceContextString(profile: profile, anchor: date, in: context)

        let payloads = try await apiClient.generateMealPlan(
            context: miraContext,
            cyclePhase: cyclePhase?.rawValue,
            isTrainingDay: isTrainingDay,
            avoidMealNames: avoidMealNames,
            pantryItems: pantryNames,
            adherenceContext: adherence
        )

        let meals = payloads.map(meal(from:))

        let plan = MealPlan(
            date: date,
            productMode: profile.productMode,
            meals: meals
        )
        context.insert(plan)

        for meal in meals {
            context.insert(meal)
        }

        let elapsed = Date().timeIntervalSince(started)
        logger.info("Plan ready for \(date.ISO8601Format(), privacy: .public) in \(elapsed, format: .fixed(precision: 2), privacy: .public)s, \(meals.count, privacy: .public) meals")

        return plan
    }

    /// Maps a Lambda meal payload onto the SwiftData Meal model. The Lambda
    /// joins cooking_instructions back into a single string with `; ` so the
    /// existing UI (which renders instructions as one paragraph) doesn't
    /// need rework — Task 1 is a contract migration, not a UI refactor.
    /// Internal so MealGeneratorParserTests can pin the mapping contract.
    func meal(from payload: MiraAPIClient.MealPlanMealPayload) -> Meal {
        let mealType = parseMealType(payload.type)
        let instructions = payload.cooking_instructions.joined(separator: "; ")
        return Meal(
            name: payload.name,
            mealType: mealType,
            proteinGrams: payload.protein_g,
            caloriesTotal: payload.calories,
            carbsGrams: payload.carbs_g,
            fatGrams: payload.fat_g,
            fiberGrams: payload.fiber_g,
            prepTimeMinutes: payload.prep_minutes,
            cookingInstructions: instructions.isEmpty ? nil : instructions,
            ingredients: payload.ingredients,
            isNauseaSafe: payload.nausea_safe,
            isHighProtein: payload.protein_g >= 25
        )
    }

    // MARK: - Weekly (sequential, with retry + cross-day dedup)

    /// Generate `days` consecutive plans starting at `startDate`. Sequential
    /// because each Mira call must fit the API gateway timeout (29s); a single
    /// 7-day prompt would exceed that. Each call after the first includes the
    /// cumulative list of meal names from prior days so Mira varies sources.
    ///
    /// Retry classification (per `MealPlanError.isRetryable`):
    /// - 5xx, transport, missing tool_use → exponential backoff (2s, 4s, 8s)
    ///   up to `maxAttempts` (default 3).
    /// - 422 schema validation, decode errors, 4xx → fail fast after one
    ///   retry. The model returned a tool_use payload that violated the
    ///   schema (e.g., zero macros); retrying usually wastes spend on the
    ///   same broken state. The malformed payload is logged from the
    ///   Lambda side via the `tool_use_parse_failure` CloudWatch metric.
    ///
    /// Days that exhaust retries are recorded in `failures` and the loop
    /// continues — partial success is still the expected outcome under
    /// network or rate-limit pressure.
    ///
    /// `onDayCompleted` fires after each day (success or terminal failure)
    /// so a UI orchestrator can update progress without polling.
    func generateWeeklyPlan(
        profile: UserProfile,
        giTriggers: [String],
        pantryItems: [PantryItem],
        days: Int = 7,
        startDate: Date = .now,
        maxAttempts: Int = 3,
        onDayCompleted: (@MainActor @Sendable (Int, Result<MealPlan, Error>) -> Void)? = nil,
        context: ModelContext
    ) async -> WeeklyPlanResult {
        var result = WeeklyPlanResult()
        var alreadyPlannedNames: [String] = []
        let calendar = Calendar.current
        let anchor = calendar.startOfDay(for: startDate)

        logger.info("Weekly gen start days=\(days, privacy: .public) anchor=\(anchor.ISO8601Format(), privacy: .public)")

        for offset in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: offset, to: anchor) else { continue }

            deactivateExistingPlans(on: date, in: context)

            let phaseForDay = cyclePhase(for: date, profile: profile)
            let trainingForDay = isTrainingDay(date, profile: profile)

            var lastError: Error?
            // Schema-validation errors get one retry max; everything else
            // gets the configured maxAttempts.
            let attemptCap = maxAttempts
            var attempt = 0
            while attempt < attemptCap {
                attempt += 1
                do {
                    let plan = try await generateDailyPlan(
                        profile: profile,
                        cyclePhase: phaseForDay,
                        giTriggers: giTriggers,
                        pantryItems: pantryItems,
                        isTrainingDay: trainingForDay,
                        date: date,
                        avoidMealNames: alreadyPlannedNames,
                        context: context
                    )
                    result.plansByDate[date] = plan.id
                    alreadyPlannedNames.append(contentsOf: plan.meals.map(\.name))
                    onDayCompleted?(offset, .success(plan))
                    lastError = nil
                    break
                } catch let mpError as MiraAPIClient.MealPlanError {
                    lastError = mpError
                    logger.warning("Day \(offset, privacy: .public) attempt \(attempt, privacy: .public) failed: \(mpError.localizedDescription, privacy: .public)")
                    if !mpError.isRetryable {
                        // Schema validation / decode / 4xx — log the
                        // failure and give up after at most one retry.
                        // The Lambda side already logged the malformed
                        // payload to CloudWatch; further attempts on the
                        // same broken state aren't free.
                        if attempt >= 2 { break }
                    }
                    if attempt < attemptCap {
                        let delay = pow(2.0, Double(attempt))
                        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    }
                } catch {
                    // Unknown error type — treat as retryable transport.
                    lastError = error
                    logger.warning("Day \(offset, privacy: .public) attempt \(attempt, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
                    if attempt < attemptCap {
                        let delay = pow(2.0, Double(attempt))
                        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    }
                }
            }

            if let lastError {
                result.failures[date] = lastError.localizedDescription
                onDayCompleted?(offset, .failure(lastError))
            }
        }

        logger.info("Weekly gen done success=\(result.successCount, privacy: .public) fail=\(result.failureCount, privacy: .public)")
        return result
    }

    // MARK: - Helpers

    private func cyclePhase(for date: Date, profile: UserProfile) -> CyclePhase? {
        guard let injectionDay = profile.injectionDay else { return nil }
        return InjectionCycleEngine.phase(forDate: date, injectionDay: injectionDay)
    }

    /// Stub for now — wire to TrainingSession queries in a follow-up. Defaults
    /// to false so meal plans don't assume the user is lifting on a given day.
    private func isTrainingDay(_ date: Date, profile: UserProfile) -> Bool {
        false
    }

    /// Marks any active plans on `date` as inactive so the new plan replaces
    /// rather than stacks. Idempotent — fine to call on a day that has nothing.
    private func deactivateExistingPlans(on date: Date, in context: ModelContext) {
        let descriptor = FetchDescriptor<MealPlan>()
        guard let plans = try? context.fetch(descriptor) else { return }
        let cal = Calendar.current
        for plan in plans where plan.isActive && cal.isDate(plan.date, inSameDayAs: date) {
            plan.isActive = false
        }
    }

    // MARK: - Adherence context (Task 5)

    /// When the adherenceContext feature flag is on, builds a 7-day
    /// adherence summary from the user's MealPlan + NutritionLog rows
    /// and renders it as a prompt fragment. Returns nil when:
    ///   - the flag is off (default)
    ///   - the user has no signal (every day untouched, no swaps)
    ///
    /// Nil short-circuits the Lambda's adherence block so we don't waste
    /// tokens on a "no data" line in the prompt for fresh users. Pure
    /// compute split between AdherenceSummary.build (data shape) and
    /// AdherenceContextFormatter.format (prompt language) so each layer
    /// is independently unit-testable.
    private func adherenceContextString(
        profile: UserProfile,
        anchor: Date,
        in context: ModelContext
    ) -> String? {
        guard FeatureFlags.shared.isEnabled(.adherenceContext) else { return nil }

        let plansDescriptor = FetchDescriptor<MealPlan>()
        let plans = (try? context.fetch(plansDescriptor)) ?? []

        let logsDescriptor = FetchDescriptor<NutritionLog>()
        let logs = (try? context.fetch(logsDescriptor)) ?? []

        let summary = AdherenceSummary.build(
            windowDays: 7,
            anchor: anchor,
            plans: plans,
            nutritionLogs: logs,
            proteinTargetGrams: profile.proteinTargetGrams
        )
        let formatted = AdherenceContextFormatter.format(summary)
        return formatted.isEmpty ? nil : formatted
    }

    // MARK: - Type mapping

    /// Maps the Lambda's enum-constrained `type` string onto SwiftData's
    /// `MealType`. The Bedrock schema's enum guarantees one of the listed
    /// strings, but we keep the mapping defensive so a tool-spec drift
    /// doesn't silently mis-categorize meals.
    private func parseMealType(_ raw: String) -> MealType {
        switch raw.lowercased() {
        case "breakfast": .breakfast
        case "lunch": .lunch
        case "dinner": .dinner
        case "snack": .snack
        case "pre-workout", "preworkout": .preWorkout
        case "post-workout", "postworkout": .postWorkout
        default: .snack
        }
    }
}
