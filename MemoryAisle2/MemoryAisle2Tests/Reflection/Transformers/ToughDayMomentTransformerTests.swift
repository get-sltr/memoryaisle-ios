import XCTest
@testable import MemoryAisle2

@MainActor
final class ToughDayMomentTransformerTests: XCTestCase {

    private let sut = ToughDayMomentTransformer()

    func test_nauseaThreeFires() throws {
        let symptom = ReflectionTestFixtures.symptom(daysAgo: 1, nausea: 3)
        let records = ReflectionSourceRecords(
            symptomLogs: [symptom],
            userProfile: ReflectionTestFixtures.profile()
        )
        let moment = try sut.moments(from: records).first
        XCTAssertNotNil(moment)
        XCTAssertEqual(moment?.title, "A tough day")
        XCTAssertEqual(moment?.category, .toughDay)
    }

    func test_nauseaBelowThreeDoesNotFire() throws {
        let symptom = ReflectionTestFixtures.symptom(daysAgo: 1, nausea: 2)
        let records = ReflectionSourceRecords(
            symptomLogs: [symptom],
            userProfile: ReflectionTestFixtures.profile()
        )
        XCTAssertEqual(try sut.moments(from: records), [])
    }

    func test_lowCaloriesFires() throws {
        let log = ReflectionTestFixtures.nutrition(daysAgo: 2, calories: 900)
        let records = ReflectionSourceRecords(
            nutritionLogs: [log],
            userProfile: ReflectionTestFixtures.profile()
        )
        XCTAssertEqual(try sut.moments(from: records).first?.title, "Low fuel day")
    }

    func test_caloriesAtThresholdDoesNotFire() throws {
        let log = ReflectionTestFixtures.nutrition(daysAgo: 2, calories: 1200)
        let records = ReflectionSourceRecords(
            nutritionLogs: [log],
            userProfile: ReflectionTestFixtures.profile()
        )
        XCTAssertEqual(try sut.moments(from: records), [])
    }

    func test_threeDayProteinMissFires() throws {
        // proteinTarget 140, so 0.7x = 98. Three days below 98 in a row.
        let logs = (0..<3).map {
            ReflectionTestFixtures.nutrition(daysAgo: $0, protein: 80)
        }
        let records = ReflectionSourceRecords(
            nutritionLogs: logs,
            userProfile: ReflectionTestFixtures.profile(proteinTarget: 140)
        )
        let moment = try sut.moments(from: records).first
        XCTAssertEqual(moment?.title, "A quieter stretch")
    }

    func test_twoDayProteinMissDoesNotFire() throws {
        let logs = (0..<2).map {
            ReflectionTestFixtures.nutrition(daysAgo: $0, protein: 80)
        }
        let records = ReflectionSourceRecords(
            nutritionLogs: logs,
            userProfile: ReflectionTestFixtures.profile(proteinTarget: 140)
        )
        XCTAssertEqual(try sut.moments(from: records), [])
    }

    func test_multipleTriggersSameDayProducesOne() throws {
        let nausea = ReflectionTestFixtures.symptom(daysAgo: 1, nausea: 4)
        let lowCal = ReflectionTestFixtures.nutrition(daysAgo: 1, calories: 800)
        let records = ReflectionSourceRecords(
            nutritionLogs: [lowCal],
            symptomLogs: [nausea],
            userProfile: ReflectionTestFixtures.profile()
        )
        let moments = try sut.moments(from: records)
        XCTAssertEqual(moments.count, 1)
        // Nausea is softest-first, so title should be the nausea variant
        XCTAssertEqual(moments[0].title, "A tough day")
    }
}
