import XCTest
@testable import MemoryAisle2

@MainActor
final class MealMomentTransformerTests: XCTestCase {

    private let sut = MealMomentTransformer()

    func test_noLogs_returnsEmpty() throws {
        let records = ReflectionSourceRecords()
        XCTAssertEqual(try sut.moments(from: records), [])
    }

    func test_logsWithoutFoodName_areSkipped() throws {
        // Reviewer seed data and HydrationTracker both write rows with no
        // foodName. Those are daily macro totals, not meal events, so they
        // must never turn into meal moments.
        let logs = [
            ReflectionTestFixtures.nutrition(daysAgo: 2, protein: 140),
            ReflectionTestFixtures.nutrition(daysAgo: 1, protein: 135),
            ReflectionTestFixtures.nutrition(daysAgo: 0, protein: 145)
        ]
        let records = ReflectionSourceRecords(nutritionLogs: logs)
        XCTAssertEqual(try sut.moments(from: records), [])
    }

    func test_singleMeal_marksAsFirstMealMilestone() throws {
        let meal = ReflectionTestFixtures.nutrition(
            daysAgo: 0,
            protein: 38,
            calories: 520,
            foodName: "Chicken Caesar Salad"
        )
        let records = ReflectionSourceRecords(nutritionLogs: [meal])

        let moments = try sut.moments(from: records)

        XCTAssertEqual(moments.count, 1)
        XCTAssertEqual(moments[0].title, "Your first meal")
        XCTAssertEqual(moments[0].category, .milestone)
        XCTAssertEqual(moments[0].type, .mealMoment)
        XCTAssertTrue(moments[0].description?.contains("Chicken Caesar Salad") == true)
        XCTAssertTrue(moments[0].description?.contains("38g") == true)
    }

    func test_multipleMeals_firstIsMilestoneRestAreStandard() throws {
        let meals = [
            ReflectionTestFixtures.nutrition(daysAgo: 2, protein: 32, foodName: "Greek yogurt bowl"),
            ReflectionTestFixtures.nutrition(daysAgo: 1, protein: 40, foodName: "Salmon and rice"),
            ReflectionTestFixtures.nutrition(daysAgo: 0, protein: 28, foodName: "Turkey wrap")
        ]
        let records = ReflectionSourceRecords(nutritionLogs: meals)

        let moments = try sut.moments(from: records)

        XCTAssertEqual(moments.count, 3)
        let firstMoment = moments.first { $0.title == "Your first meal" }
        XCTAssertNotNil(firstMoment)
        XCTAssertEqual(firstMoment?.category, .milestone)

        let standardMoments = moments.filter { $0.category == .standard }
        XCTAssertEqual(standardMoments.count, 2)
        XCTAssertTrue(standardMoments.contains { $0.title == "Salmon and rice" })
        XCTAssertTrue(standardMoments.contains { $0.title == "Turkey wrap" })
    }

    func test_photoData_passesThroughSoPhotosFilterPicksItUp() throws {
        let photo = Data([0x01, 0x02, 0x03, 0x04])
        let meal = ReflectionTestFixtures.nutrition(
            daysAgo: 0,
            protein: 30,
            foodName: "Eggs and avocado",
            photo: photo
        )
        let records = ReflectionSourceRecords(nutritionLogs: [meal])

        let moments = try sut.moments(from: records)

        XCTAssertEqual(moments.count, 1)
        XCTAssertEqual(moments[0].photoData, photo)
        // The Photos filter chip matches any moment with photoData != nil,
        // so passing photo bytes through is how meal photos become visible
        // under both the Meals and Photos chips without special-casing.
        XCTAssertTrue(ReflectionFilter.photos.matches(moments[0]))
        XCTAssertTrue(ReflectionFilter.meals.matches(moments[0]))
    }

    func test_mixedNamedAndUnnamedLogs_onlyNamedBecomeMoments() throws {
        // Simulates a reviewer device: 7 days of seed totals with no names,
        // then the reviewer actually snaps a meal photo on top. Only the
        // named row becomes a meal moment; seed totals feed other
        // transformers via stats and streaks.
        var logs: [NutritionLog] = (0..<7).map {
            ReflectionTestFixtures.nutrition(daysAgo: 6 - $0, protein: 140)
        }
        logs.append(
            ReflectionTestFixtures.nutrition(
                daysAgo: 0,
                protein: 35,
                foodName: "Grilled chicken and greens"
            )
        )
        let records = ReflectionSourceRecords(nutritionLogs: logs)

        let moments = try sut.moments(from: records)

        XCTAssertEqual(moments.count, 1)
        XCTAssertEqual(moments[0].title, "Your first meal")
    }

    func test_voice_descriptionAvoidsBannedVocabulary() throws {
        // Mira voice rules forbid clinical/judgy vocabulary in any generated
        // copy. Keep the list in sync with project_mira_voice.md.
        let banned = [
            "off-track", "behind", "missed", "deficit",
            "failed", "fell short", "below target",
            "stalled", "plateau", "flat"
        ]
        let meals = [
            ReflectionTestFixtures.nutrition(daysAgo: 2, protein: 40, foodName: "Steak"),
            ReflectionTestFixtures.nutrition(daysAgo: 1, protein: 25, foodName: "Yogurt bowl"),
            ReflectionTestFixtures.nutrition(daysAgo: 0, protein: 10, foodName: "Toast")
        ]
        let records = ReflectionSourceRecords(nutritionLogs: meals)

        let moments = try sut.moments(from: records)

        for moment in moments {
            let description = (moment.description ?? "").lowercased()
            for word in banned {
                XCTAssertFalse(
                    description.contains(word),
                    "Meal moment description contained banned word '\(word)': \(description)"
                )
            }
        }
    }
}
