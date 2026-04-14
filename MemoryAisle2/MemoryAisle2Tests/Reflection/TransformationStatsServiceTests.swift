import XCTest
@testable import MemoryAisle2

@MainActor
final class TransformationStatsServiceTests: XCTestCase {

    private let sut = TransformationStatsService()

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "journeyStartDate")
    }

    func test_lossGoal_computesLbsLost() {
        let start = ReflectionTestFixtures.bodyComp(daysAgo: 30, weightLbs: 200)
        let current = ReflectionTestFixtures.bodyComp(daysAgo: 0, weightLbs: 188)
        let records = ReflectionSourceRecords(
            bodyCompositions: [start, current],
            userProfile: ReflectionTestFixtures.profile(weightLbs: 200, goalWeightLbs: 175)
        )
        let stats = sut.stats(from: records)
        XCTAssertEqual(stats.lbsDelta, 12)
        XCTAssertEqual(stats.direction, .lost)
    }

    func test_gainGoal_computesLbsGained() {
        let start = ReflectionTestFixtures.bodyComp(daysAgo: 30, weightLbs: 155)
        let current = ReflectionTestFixtures.bodyComp(daysAgo: 0, weightLbs: 162)
        let records = ReflectionSourceRecords(
            bodyCompositions: [start, current],
            userProfile: ReflectionTestFixtures.profile(weightLbs: 155, goalWeightLbs: 175)
        )
        let stats = sut.stats(from: records)
        XCTAssertEqual(stats.lbsDelta, 7)
        XCTAssertEqual(stats.direction, .gained)
    }

    func test_lossGoalButGained_clampsToZero() {
        let start = ReflectionTestFixtures.bodyComp(daysAgo: 30, weightLbs: 200)
        let current = ReflectionTestFixtures.bodyComp(daysAgo: 0, weightLbs: 205)
        let records = ReflectionSourceRecords(
            bodyCompositions: [start, current],
            userProfile: ReflectionTestFixtures.profile(weightLbs: 200, goalWeightLbs: 175)
        )
        let stats = sut.stats(from: records)
        XCTAssertEqual(stats.lbsDelta, 0)
        XCTAssertEqual(stats.direction, .lost)
    }

    func test_leanMassDelta_computedWhenAvailable() {
        let start = ReflectionTestFixtures.bodyComp(daysAgo: 30, weightLbs: 200, leanMass: 140)
        let current = ReflectionTestFixtures.bodyComp(daysAgo: 0, weightLbs: 188, leanMass: 138)
        let records = ReflectionSourceRecords(
            bodyCompositions: [start, current],
            userProfile: ReflectionTestFixtures.profile()
        )
        XCTAssertEqual(sut.stats(from: records).leanDelta, -2)
    }

    func test_leanMassDelta_nilWhenUncomputable() {
        let start = ReflectionTestFixtures.bodyComp(daysAgo: 30, weightLbs: 200)
        let current = ReflectionTestFixtures.bodyComp(daysAgo: 0, weightLbs: 188)
        let records = ReflectionSourceRecords(
            bodyCompositions: [start, current],
            userProfile: ReflectionTestFixtures.profile()
        )
        XCTAssertNil(sut.stats(from: records).leanDelta)
    }

    func test_daysFromUserDefaults() {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: .now)!
        UserDefaults.standard.set(thirtyDaysAgo, forKey: "journeyStartDate")
        let records = ReflectionSourceRecords(userProfile: ReflectionTestFixtures.profile())
        XCTAssertEqual(sut.stats(from: records).days, 30)
    }

    func test_daysFallsBackToEarliestBodyComposition() {
        let bc = ReflectionTestFixtures.bodyComp(daysAgo: 14, weightLbs: 200)
        let records = ReflectionSourceRecords(
            bodyCompositions: [bc],
            userProfile: ReflectionTestFixtures.profile()
        )
        XCTAssertEqual(sut.stats(from: records).days, 14)
    }

    func test_noAnchor_daysIsNil() {
        let records = ReflectionSourceRecords(userProfile: ReflectionTestFixtures.profile())
        XCTAssertNil(sut.stats(from: records).days)
    }
}
