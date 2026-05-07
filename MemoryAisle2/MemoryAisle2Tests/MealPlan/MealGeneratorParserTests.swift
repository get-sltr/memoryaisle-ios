import XCTest
@testable import MemoryAisle2

/// Pins the iOS-side contract for the meal-plan tool_use migration (Task 1).
///
/// Server-side schema enforcement + payload validation live in the Lambda's
/// `meal-plan-schema.mjs` and are unit-tested in `Infrastructure/lambda/
/// miraGenerate/test.mjs` (run with `node --test`). These tests cover the
/// two iOS-side responsibilities that the Lambda can't see:
///   1. Mapping a successful Lambda payload onto the SwiftData Meal model
///      without losing fields or mis-categorizing meal types.
///   2. Classifying MealPlanError so the weekly retry loop knows when to
///      back off and when to fail fast.
///
/// The pre-Task-1 pipe-delimited parser and its fallbackMeals safety net
/// are intentionally gone — the prior tests pinned a parser that silently
/// substituted hardcoded meals on Mira refusal, which was the bug
/// generating zero-macro rows on the dashboard.
@MainActor
final class MealGeneratorParserTests: XCTestCase {

    private var generator: MealGenerator { MealGenerator() }

    // MARK: - Payload → Meal mapping

    func test_validPayloadMapsAllFieldsOntoMealModel() {
        let payload = MiraAPIClient.MealPlanMealPayload(
            type: "breakfast",
            name: "Greek yogurt parfait with berries.",
            protein_g: 28,
            calories: 320,
            carbs_g: 30,
            fat_g: 10,
            fiber_g: 5,
            prep_minutes: 4,
            nausea_safe: true,
            ingredients: ["1 cup Greek yogurt", "1/2 cup mixed berries", "1 tbsp honey"],
            cooking_instructions: [
                "Spoon yogurt into a bowl.",
                "Top with berries.",
                "Drizzle with honey."
            ]
        )

        let meal = generator.meal(from: payload)

        XCTAssertEqual(meal.name, "Greek yogurt parfait with berries.")
        XCTAssertEqual(meal.mealType, .breakfast)
        XCTAssertEqual(meal.proteinGrams, 28, accuracy: 0.01)
        XCTAssertEqual(meal.caloriesTotal, 320, accuracy: 0.01)
        XCTAssertEqual(meal.carbsGrams, 30, accuracy: 0.01)
        XCTAssertEqual(meal.fatGrams, 10, accuracy: 0.01)
        XCTAssertEqual(meal.fiberGrams, 5, accuracy: 0.01)
        XCTAssertEqual(meal.prepTimeMinutes, 4)
        XCTAssertTrue(meal.isNauseaSafe)
        XCTAssertTrue(meal.isHighProtein) // 28g >= 25g threshold
        XCTAssertEqual(meal.ingredients.count, 3)
        XCTAssertEqual(meal.ingredients.first, "1 cup Greek yogurt")
    }

    func test_cookingInstructionsAreJoinedForBackwardCompatibility() {
        // The Lambda returns cooking_instructions as [String]; the existing
        // UI renders Meal.cookingInstructions as one paragraph. The mapper
        // joins with "; " so the UI keeps working without a refactor.
        let payload = makePayload(
            cooking_instructions: ["Step one.", "Step two.", "Step three."]
        )
        let meal = generator.meal(from: payload)
        XCTAssertEqual(meal.cookingInstructions, "Step one.; Step two.; Step three.")
    }

    func test_emptyCookingInstructionsBecomeNil() {
        // Defense for the schema slipping past empty arrays — the validator
        // rejects this server-side, but the mapper still has to do
        // something sane if a payload sneaks through.
        let payload = makePayload(cooking_instructions: [])
        let meal = generator.meal(from: payload)
        XCTAssertNil(meal.cookingInstructions)
    }

    func test_isHighProteinThresholdIsExactly25g() {
        let underThreshold = generator.meal(from: makePayload(protein_g: 24.9))
        let atThreshold = generator.meal(from: makePayload(protein_g: 25.0))
        let overThreshold = generator.meal(from: makePayload(protein_g: 25.1))
        XCTAssertFalse(underThreshold.isHighProtein)
        XCTAssertTrue(atThreshold.isHighProtein)
        XCTAssertTrue(overThreshold.isHighProtein)
    }

    // MARK: - Meal type mapping

    func test_allLambdaEnumValuesMapToCorrectMealType() {
        let cases: [(String, MealType)] = [
            ("breakfast", .breakfast),
            ("lunch", .lunch),
            ("dinner", .dinner),
            ("snack", .snack),
            ("pre-workout", .preWorkout),
            ("post-workout", .postWorkout)
        ]
        for (raw, expected) in cases {
            let meal = generator.meal(from: makePayload(type: raw))
            XCTAssertEqual(meal.mealType, expected, "type=\(raw)")
        }
    }

    func test_unknownMealTypeFallsBackToSnack() {
        // Defense: schema constrains type to the enum, but if a tool-spec
        // drift slips a new value through, default to snack rather than
        // crashing.
        let meal = generator.meal(from: makePayload(type: "midnightsnack"))
        XCTAssertEqual(meal.mealType, .snack)
    }

    func test_camelCaseWorkoutVariants() {
        XCTAssertEqual(
            generator.meal(from: makePayload(type: "preworkout")).mealType,
            .preWorkout
        )
        XCTAssertEqual(
            generator.meal(from: makePayload(type: "postworkout")).mealType,
            .postWorkout
        )
    }

    // MARK: - MealPlanError retry classification

    func test_schemaValidationErrorIsNotRetryable() {
        let error = MiraAPIClient.MealPlanError.schemaValidation(
            details: ["meals[0].protein_g: must be > 0"]
        )
        XCTAssertFalse(error.isRetryable)
    }

    func test_decodeErrorIsNotRetryable() {
        struct StubError: Error {}
        let error = MiraAPIClient.MealPlanError.decode(StubError())
        XCTAssertFalse(error.isRetryable)
    }

    func test_serverError5xxIsRetryable() {
        XCTAssertTrue(
            MiraAPIClient.MealPlanError.server(status: 500, message: "boom").isRetryable
        )
        XCTAssertTrue(
            MiraAPIClient.MealPlanError.server(status: 503, message: "throttle").isRetryable
        )
    }

    func test_serverError4xxIsNotRetryable() {
        XCTAssertFalse(
            MiraAPIClient.MealPlanError.server(status: 400, message: "bad").isRetryable
        )
        XCTAssertFalse(
            MiraAPIClient.MealPlanError.server(status: 401, message: "auth").isRetryable
        )
    }

    func test_transportErrorIsRetryable() {
        struct StubError: Error {}
        XCTAssertTrue(MiraAPIClient.MealPlanError.transport(StubError()).isRetryable)
    }

    func test_noToolUseBlockIsRetryable() {
        // Model refused or hit max_tokens. Retrying often works because
        // sampling variance can produce a tool_use call on the next try.
        XCTAssertTrue(MiraAPIClient.MealPlanError.noToolUseBlock.isRetryable)
    }

    // MARK: - Helpers

    private func makePayload(
        type: String = "lunch",
        name: String = "Test meal.",
        protein_g: Double = 30,
        calories: Double = 450,
        carbs_g: Double = 40,
        fat_g: Double = 12,
        fiber_g: Double = 6,
        prep_minutes: Int = 15,
        nausea_safe: Bool = false,
        ingredients: [String] = ["6oz chicken breast", "1 cup rice"],
        cooking_instructions: [String] = ["Cook chicken.", "Cook rice.", "Combine."]
    ) -> MiraAPIClient.MealPlanMealPayload {
        MiraAPIClient.MealPlanMealPayload(
            type: type,
            name: name,
            protein_g: protein_g,
            calories: calories,
            carbs_g: carbs_g,
            fat_g: fat_g,
            fiber_g: fiber_g,
            prep_minutes: prep_minutes,
            nausea_safe: nausea_safe,
            ingredients: ingredients,
            cooking_instructions: cooking_instructions
        )
    }
}
