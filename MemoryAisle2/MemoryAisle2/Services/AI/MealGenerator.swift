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

    /// Generate one day's meal plan. The optional `date` lets callers schedule
    /// future days; `avoidMealNames` is the cumulative list of meal names already
    /// planned earlier in the week, so Mira varies the protein source and meal
    /// style across the seven days.
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

        let systemPrompt = MiraEngine.buildSystemPrompt(
            profile: profile,
            cyclePhase: cyclePhase,
            giTriggers: giTriggers,
            pantryItems: pantryItems
        )

        let mealRequest = buildMealRequest(
            profile: profile,
            cyclePhase: cyclePhase,
            isTrainingDay: isTrainingDay,
            pantry: pantryItems,
            avoidMealNames: avoidMealNames
        )

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

        let response = try await apiClient.send(
            message: "\(systemPrompt)\n\n\(mealRequest)",
            context: miraContext
        )

        let meals = parseMeals(from: response, profile: profile)

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

    // MARK: - Weekly (sequential, with retry + cross-day dedup)

    /// Generate `days` consecutive plans starting at `startDate`. Sequential
    /// because each Mira call must fit the API gateway timeout (29s); a single
    /// 7-day prompt would exceed that. Each call after the first includes the
    /// cumulative list of meal names from prior days so Mira varies sources.
    ///
    /// Per-day retries with exponential backoff (2s, 4s, 8s) up to `maxAttempts`.
    /// Days that exhaust retries are recorded in `failures` and the loop
    /// continues — partial success is the expected outcome under network or
    /// rate-limit pressure.
    ///
    /// `onDayCompleted` fires after each day (success or terminal failure) so
    /// a UI orchestrator can update progress without polling.
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
            for attempt in 1...maxAttempts {
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
                } catch {
                    lastError = error
                    logger.warning("Day \(offset, privacy: .public) attempt \(attempt, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
                    if attempt < maxAttempts {
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

    // MARK: - Prompt construction

    private func buildMealRequest(
        profile: UserProfile,
        cyclePhase: CyclePhase?,
        isTrainingDay: Bool,
        pantry: [PantryItem],
        avoidMealNames: [String]
    ) -> String {
        let mealCount = isTrainingDay ? 5 : 4
        let restrictions = profile.dietaryRestrictions
            .map(\.rawValue).joined(separator: ", ")

        var request = """
        Generate \(mealCount) meals for today. \
        Protein target: \(profile.proteinTargetGrams)g total. \
        Calorie target: \(profile.calorieTarget) total.
        """

        if isTrainingDay {
            request += " Include pre-workout and post-workout meals."
        }

        if let phase = cyclePhase {
            request += " Cycle phase: \(phase.rawValue). \(phase.proteinStrategy)"
        }

        if !restrictions.isEmpty {
            request += " Dietary restrictions: \(restrictions)."
        }

        if !pantry.isEmpty {
            let available = pantry.prefix(15)
                .map(\.name).joined(separator: ", ")
            request += " Available in pantry: \(available)."
        }

        if !avoidMealNames.isEmpty {
            // Cap at 20 names so the prompt stays bounded; the most recent are
            // the most likely repeats so we keep the tail.
            let recentNames = avoidMealNames.suffix(20)
            let avoid = recentNames.joined(separator: ", ")
            request += " Already planned earlier this week, vary protein source and meal style and do NOT repeat exactly: \(avoid)."
        }

        request += """

        For each meal, provide a COMPLETE cookbook-style recipe.
        Respond in this exact format for each meal:
        MEAL|type|name|protein_g|calories|carbs_g|fat_g|fiber_g|\
        prep_minutes|nausea_safe|ingredients(semicolon-separated with amounts)|\
        cooking_instructions(numbered steps separated by semicolons)
        Types: breakfast, lunch, dinner, snack, pre-workout, post-workout

        For ingredients, include exact measurements (e.g., "8oz chicken breast;1 cup brown rice;2 cups broccoli florets;1 tbsp olive oil;salt and pepper to taste").
        For instructions, write detailed numbered steps (e.g., "1. Preheat oven to 400F;2. Season chicken with salt and pepper;3. Sear 3 min per side;4. Bake 15 min at 400F;5. Rest 5 min before slicing").
        Include a GLP-1 tip at the end of instructions if relevant.
        """

        return request
    }

    // MARK: - Parsing (kept package-internal so tests can hit it)

    func parseMeals(
        from response: String,
        profile: UserProfile
    ) -> [Meal] {
        let lines = response.components(separatedBy: "\n")
            .filter { $0.hasPrefix("MEAL|") }

        var meals: [Meal] = []

        for line in lines {
            let parts = line.components(separatedBy: "|")
            guard parts.count >= 10 else { continue }

            let mealType = parseMealType(parts[1].trimmingCharacters(in: .whitespaces))
            let name = parts[2].trimmingCharacters(in: .whitespaces)
            let protein = Double(parts[3].trimmingCharacters(in: .whitespaces)) ?? 0
            let calories = Double(parts[4].trimmingCharacters(in: .whitespaces)) ?? 0
            let carbs = Double(parts[5].trimmingCharacters(in: .whitespaces)) ?? 0
            let fat = Double(parts[6].trimmingCharacters(in: .whitespaces)) ?? 0
            let fiber = Double(parts[7].trimmingCharacters(in: .whitespaces)) ?? 0
            let prep = Int(parts[8].trimmingCharacters(in: .whitespaces)) ?? 15
            let nauseaSafe = parts[9].trimmingCharacters(in: .whitespaces).lowercased() == "true"

            let ingredients: [String]
            if parts.count > 10 {
                ingredients = parts[10].components(separatedBy: ";")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
            } else {
                ingredients = []
            }

            let instructions: String?
            if parts.count > 11 {
                instructions = parts[11].trimmingCharacters(in: .whitespaces)
            } else {
                instructions = nil
            }

            let meal = Meal(
                name: name,
                mealType: mealType,
                proteinGrams: protein,
                caloriesTotal: calories,
                carbsGrams: carbs,
                fatGrams: fat,
                fiberGrams: fiber,
                prepTimeMinutes: prep,
                cookingInstructions: instructions,
                ingredients: ingredients,
                isNauseaSafe: nauseaSafe,
                isHighProtein: protein >= 25
            )
            meals.append(meal)
        }

        if meals.isEmpty {
            return fallbackMeals(profile: profile)
        }

        return meals
    }

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

    private func fallbackMeals(profile: UserProfile) -> [Meal] {
        let perMeal = Double(profile.proteinTargetGrams) / 4.0
        let calPerMeal = Double(profile.calorieTarget) / 4.0

        return [
            Meal(
                name: "Protein-packed breakfast",
                mealType: .breakfast,
                proteinGrams: perMeal * 1.1,
                caloriesTotal: calPerMeal,
                isNauseaSafe: true,
                isHighProtein: true
            ),
            Meal(
                name: "Lean lunch bowl",
                mealType: .lunch,
                proteinGrams: perMeal * 1.1,
                caloriesTotal: calPerMeal * 1.1,
                isHighProtein: true
            ),
            Meal(
                name: "Protein snack",
                mealType: .snack,
                proteinGrams: perMeal * 0.6,
                caloriesTotal: calPerMeal * 0.5,
                isNauseaSafe: true,
                isHighProtein: true
            ),
            Meal(
                name: "Balanced dinner",
                mealType: .dinner,
                proteinGrams: perMeal * 1.2,
                caloriesTotal: calPerMeal * 1.4,
                isHighProtein: true
            )
        ]
    }
}
