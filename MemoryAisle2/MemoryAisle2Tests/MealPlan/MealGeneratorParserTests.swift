import XCTest
@testable import MemoryAisle2

/// Parser correctness for the pipe-delimited Mira meal output. The format is
/// the contract between Mira's prompt and the iOS client; if the parser
/// silently drops a meal, users see a half-built day and protein targets are
/// undercounted. These tests pin the boundary cases.
@MainActor
final class MealGeneratorParserTests: XCTestCase {

    private let profile = UserProfile(
        name: "Test",
        productMode: .everyday,
        proteinTargetGrams: 130,
        calorieTarget: 1600
    )

    private var generator: MealGenerator { MealGenerator() }

    // MARK: - Happy path

    func test_singleWellFormedMealLine_parses() {
        let response = """
        Some preamble Mira may write.
        MEAL|breakfast|Greek yogurt with berries|28|320|30|10|5|4|true|2 cup yogurt;1 cup berries;1 tbsp honey|1. Combine yogurt and berries;2. Drizzle honey
        """

        let meals = generator.parseMeals(from: response, profile: profile)
        XCTAssertEqual(meals.count, 1)

        let meal = meals[0]
        XCTAssertEqual(meal.name, "Greek yogurt with berries")
        XCTAssertEqual(meal.mealType, .breakfast)
        XCTAssertEqual(meal.proteinGrams, 28, accuracy: 0.01)
        XCTAssertEqual(meal.caloriesTotal, 320, accuracy: 0.01)
        XCTAssertEqual(meal.prepTimeMinutes, 4)
        XCTAssertTrue(meal.isNauseaSafe)
        XCTAssertTrue(meal.isHighProtein) // 28g >= 25g threshold
        XCTAssertEqual(meal.ingredients.count, 3)
        XCTAssertNotNil(meal.cookingInstructions)
    }

    func test_fourMealLines_allParse() {
        let response = """
        MEAL|breakfast|Eggs and toast|22|350|30|12|4|10|true|3 eggs;2 slices toast|1. Scramble;2. Toast
        MEAL|lunch|Chicken bowl|38|450|45|10|6|15|false|6oz chicken;1 cup rice|1. Cook
        MEAL|dinner|Salmon plate|35|420|20|18|5|20|false|6oz salmon;greens|1. Sear
        MEAL|snack|Protein shake|25|180|10|3|2|2|true|1 scoop whey;water|1. Blend
        """

        let meals = generator.parseMeals(from: response, profile: profile)
        XCTAssertEqual(meals.count, 4)
        XCTAssertEqual(Set(meals.map(\.mealType)), [.breakfast, .lunch, .dinner, .snack])
    }

    // MARK: - Malformed input

    func test_lineWithFewerThan10Pipes_isSkipped() {
        let response = """
        MEAL|breakfast|Eggs|22|350|30
        MEAL|lunch|Salad|18|400|35|8|6|10|true|greens|1. Toss
        """

        let meals = generator.parseMeals(from: response, profile: profile)
        XCTAssertEqual(meals.count, 1)
        XCTAssertEqual(meals[0].mealType, .lunch)
    }

    func test_unknownMealType_fallsBackToSnack() {
        let response = "MEAL|midnightsnack|Yogurt|15|150|10|5|2|2|true||"
        let meals = generator.parseMeals(from: response, profile: profile)
        XCTAssertEqual(meals.count, 1)
        XCTAssertEqual(meals[0].mealType, .snack)
    }

    func test_nonNumericProtein_treatedAsZero_butMealStillCreated() {
        let response = "MEAL|lunch|Mystery bowl|abc|400|35|8|6|10|true||"
        let meals = generator.parseMeals(from: response, profile: profile)
        XCTAssertEqual(meals.count, 1)
        XCTAssertEqual(meals[0].proteinGrams, 0)
        XCTAssertFalse(meals[0].isHighProtein)
    }

    // MARK: - Empty / fallback

    func test_responseWithNoMealLines_returnsFallbackMeals() {
        let response = "I'm sorry, I couldn't generate meals right now."
        let meals = generator.parseMeals(from: response, profile: profile)

        // Fallback returns 4 default meals so the user isn't left empty.
        XCTAssertEqual(meals.count, 4)
        XCTAssertEqual(Set(meals.map(\.mealType)), [.breakfast, .lunch, .snack, .dinner])
    }

    func test_emptyResponse_returnsFallback() {
        let meals = generator.parseMeals(from: "", profile: profile)
        XCTAssertEqual(meals.count, 4)
    }

    // MARK: - Variant labels

    func test_preWorkoutLabel_acceptsHyphenAndCamelVariants() {
        let r1 = "MEAL|pre-workout|Banana|3|100|25|0|2|2|true||"
        let r2 = "MEAL|preworkout|Toast|5|180|30|2|3|3|true||"
        XCTAssertEqual(generator.parseMeals(from: r1, profile: profile)[0].mealType, .preWorkout)
        XCTAssertEqual(generator.parseMeals(from: r2, profile: profile)[0].mealType, .preWorkout)
    }
}
