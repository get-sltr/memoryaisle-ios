import XCTest
@testable import MemoryAisle2

@MainActor
final class ProteinStreakMomentTransformerTests: XCTestCase {

    private let sut = ProteinStreakMomentTransformer()

    func test_noLogs_returnsEmpty() throws {
        let records = ReflectionSourceRecords(
            userProfile: ReflectionTestFixtures.profile(proteinTarget: 140)
        )
        XCTAssertEqual(try sut.moments(from: records), [])
    }

    func test_belowSevenDays_producesNoMoment() throws {
        let logs = (0..<6).map {
            ReflectionTestFixtures.nutrition(daysAgo: $0, protein: 150)
        }
        let records = ReflectionSourceRecords(
            nutritionLogs: logs,
            userProfile: ReflectionTestFixtures.profile(proteinTarget: 140)
        )
        XCTAssertEqual(try sut.moments(from: records), [])
    }

    func test_exactlySevenDays_producesSevenDayMoment() throws {
        let logs = (0..<7).map {
            ReflectionTestFixtures.nutrition(daysAgo: $0, protein: 150)
        }
        let records = ReflectionSourceRecords(
            nutritionLogs: logs,
            userProfile: ReflectionTestFixtures.profile(proteinTarget: 140)
        )
        let moments = try sut.moments(from: records)
        XCTAssertEqual(moments.count, 1)
        XCTAssertEqual(moments[0].title, "7 days of protein")
        XCTAssertEqual(moments[0].category, .milestone)
    }

    func test_fourteenDays_producesBothSevenAndFourteen() throws {
        let logs = (0..<14).map {
            ReflectionTestFixtures.nutrition(daysAgo: $0, protein: 150)
        }
        let records = ReflectionSourceRecords(
            nutritionLogs: logs,
            userProfile: ReflectionTestFixtures.profile(proteinTarget: 140)
        )
        let moments = try sut.moments(from: records)
        XCTAssertEqual(moments.count, 2)
        XCTAssertTrue(moments.contains { $0.title == "7 days of protein" })
        XCTAssertTrue(moments.contains { $0.title == "Two weeks strong" })
    }

    func test_brokenStreakThenRestart_producesTwoSevenDayMoments() throws {
        var logs: [NutritionLog] = []
        // First streak: days 20-14 (7 days, hit target)
        for day in 14...20 {
            logs.append(ReflectionTestFixtures.nutrition(daysAgo: day, protein: 150))
        }
        // Gap: day 13 missed
        logs.append(ReflectionTestFixtures.nutrition(daysAgo: 13, protein: 80))
        // Second streak: days 12-6 (7 days, hit target)
        for day in 6...12 {
            logs.append(ReflectionTestFixtures.nutrition(daysAgo: day, protein: 150))
        }
        let records = ReflectionSourceRecords(
            nutritionLogs: logs,
            userProfile: ReflectionTestFixtures.profile(proteinTarget: 140)
        )
        let sevenDayMoments = try sut.moments(from: records)
            .filter { $0.title == "7 days of protein" }
        XCTAssertEqual(sevenDayMoments.count, 2)
    }

    func test_missedDayInMiddle_doesNotFire() throws {
        var logs = (0..<7).map {
            ReflectionTestFixtures.nutrition(daysAgo: $0, protein: 150)
        }
        logs[3] = ReflectionTestFixtures.nutrition(daysAgo: 3, protein: 80)
        let records = ReflectionSourceRecords(
            nutritionLogs: logs,
            userProfile: ReflectionTestFixtures.profile(proteinTarget: 140)
        )
        XCTAssertEqual(try sut.moments(from: records), [])
    }
}
