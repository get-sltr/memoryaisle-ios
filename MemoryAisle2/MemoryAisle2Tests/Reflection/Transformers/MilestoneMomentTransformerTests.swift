import XCTest
@testable import MemoryAisle2

@MainActor
final class MilestoneMomentTransformerTests: XCTestCase {

    private let sut = MilestoneMomentTransformer()

    func test_lossGoal_fivePoundCrossing_fires() throws {
        // Start 200, goal 175. Current 195 → crossed 5 lbs down.
        let start = ReflectionTestFixtures.bodyComp(daysAgo: 30, weightLbs: 200)
        let current = ReflectionTestFixtures.bodyComp(daysAgo: 0, weightLbs: 195)
        let records = ReflectionSourceRecords(
            bodyCompositions: [start, current],
            userProfile: ReflectionTestFixtures.profile(weightLbs: 200, goalWeightLbs: 175)
        )
        let moments = try sut.moments(from: records)
        XCTAssertTrue(moments.contains { $0.title == "5 pounds down" })
    }

    func test_gainGoal_fivePoundCrossing_fires() throws {
        let start = ReflectionTestFixtures.bodyComp(daysAgo: 30, weightLbs: 155)
        let current = ReflectionTestFixtures.bodyComp(daysAgo: 0, weightLbs: 161)
        let records = ReflectionSourceRecords(
            bodyCompositions: [start, current],
            userProfile: ReflectionTestFixtures.profile(weightLbs: 155, goalWeightLbs: 175)
        )
        let moments = try sut.moments(from: records)
        XCTAssertTrue(moments.contains { $0.title == "5 pounds up" })
    }

    func test_tenPoundCrossing_hasDoubleDigitsCopy() throws {
        let start = ReflectionTestFixtures.bodyComp(daysAgo: 60, weightLbs: 200)
        let current = ReflectionTestFixtures.bodyComp(daysAgo: 0, weightLbs: 189)
        let records = ReflectionSourceRecords(
            bodyCompositions: [start, current],
            userProfile: ReflectionTestFixtures.profile(weightLbs: 200, goalWeightLbs: 175)
        )
        let tenMoment = try sut.moments(from: records)
            .first { $0.title == "10 pounds down" }
        XCTAssertNotNil(tenMoment)
        XCTAssertEqual(tenMoment?.description, "Double digits. That is a real one.")
    }

    func test_firstPhotoMilestone_fires() throws {
        let data = Data([0xFF])
        let bc = ReflectionTestFixtures.bodyComp(photo: data)
        let records = ReflectionSourceRecords(
            bodyCompositions: [bc],
            userProfile: ReflectionTestFixtures.profile()
        )
        let moments = try sut.moments(from: records)
        XCTAssertTrue(moments.contains { $0.id == "milestoneFirstPhoto" })
    }

    func test_noPhoto_noFirstPhotoMilestone() throws {
        let bc = ReflectionTestFixtures.bodyComp(photo: nil)
        let records = ReflectionSourceRecords(
            bodyCompositions: [bc],
            userProfile: ReflectionTestFixtures.profile()
        )
        let moments = try sut.moments(from: records)
        XCTAssertFalse(moments.contains { $0.id == "milestoneFirstPhoto" })
    }

    func test_goalReached_fires() throws {
        let start = ReflectionTestFixtures.bodyComp(daysAgo: 120, weightLbs: 200)
        let current = ReflectionTestFixtures.bodyComp(daysAgo: 0, weightLbs: 175)
        let records = ReflectionSourceRecords(
            bodyCompositions: [start, current],
            userProfile: ReflectionTestFixtures.profile(weightLbs: 200, goalWeightLbs: 175)
        )
        let atGoal = try sut.moments(from: records)
            .first { $0.id == "milestoneGoalReached" }
        XCTAssertNotNil(atGoal)
    }

    func test_noDoubleFiring() throws {
        let start = ReflectionTestFixtures.bodyComp(daysAgo: 30, weightLbs: 200)
        let mid1 = ReflectionTestFixtures.bodyComp(daysAgo: 15, weightLbs: 195)
        let mid2 = ReflectionTestFixtures.bodyComp(daysAgo: 10, weightLbs: 193)
        let current = ReflectionTestFixtures.bodyComp(daysAgo: 0, weightLbs: 190)
        let records = ReflectionSourceRecords(
            bodyCompositions: [start, mid1, mid2, current],
            userProfile: ReflectionTestFixtures.profile(weightLbs: 200, goalWeightLbs: 175)
        )
        let fivePound = try sut.moments(from: records)
            .filter { $0.title == "5 pounds down" }
        XCTAssertEqual(fivePound.count, 1)
    }
}
