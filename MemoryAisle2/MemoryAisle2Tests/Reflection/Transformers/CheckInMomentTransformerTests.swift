import XCTest
@testable import MemoryAisle2

@MainActor
final class CheckInMomentTransformerTests: XCTestCase {

    private let sut = CheckInMomentTransformer()

    func test_noRecords_returnsEmpty() throws {
        let records = ReflectionSourceRecords()
        XCTAssertEqual(try sut.moments(from: records), [])
    }

    func test_oneManualRecord_producesOneMoment() throws {
        let bc = ReflectionTestFixtures.bodyComp(daysAgo: 0, weightLbs: 180)
        let records = ReflectionSourceRecords(
            bodyCompositions: [bc],
            userProfile: ReflectionTestFixtures.profile()
        )
        let result = try sut.moments(from: records)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].type, .checkIn)
        XCTAssertEqual(result[0].category, .standard)
    }

    func test_healthKitRecord_isSkipped() throws {
        let bc = ReflectionTestFixtures.bodyComp(source: .healthKit)
        let records = ReflectionSourceRecords(
            bodyCompositions: [bc],
            userProfile: ReflectionTestFixtures.profile()
        )
        XCTAssertEqual(try sut.moments(from: records), [])
    }

    func test_firstCheckIn_hasSpecialCopy() throws {
        let bc = ReflectionTestFixtures.bodyComp(daysAgo: 0, weightLbs: 180)
        let records = ReflectionSourceRecords(
            bodyCompositions: [bc],
            userProfile: ReflectionTestFixtures.profile(weightLbs: 180)
        )
        let moment = try sut.moments(from: records).first
        XCTAssertEqual(moment?.description, "Your very first check-in. This is where the story starts.")
    }

    func test_towardGoalCheckIn_hasProgressCopy() throws {
        // Loss goal: profile start 180, goal 165, previous check-in 180, current 178
        let older = ReflectionTestFixtures.bodyComp(daysAgo: 7, weightLbs: 180)
        let newer = ReflectionTestFixtures.bodyComp(daysAgo: 0, weightLbs: 178)
        let records = ReflectionSourceRecords(
            bodyCompositions: [older, newer],
            userProfile: ReflectionTestFixtures.profile(weightLbs: 180, goalWeightLbs: 165)
        )
        let moments = try sut.moments(from: records)
        let latest = moments.first { $0.id == "checkin-\(newer.id)" }
        XCTAssertNotNil(latest)
        XCTAssertTrue(latest?.description?.contains("closer to your goal") ?? false)
    }

    func test_flatWeightCheckIn_hasShowUpCopy() throws {
        let older = ReflectionTestFixtures.bodyComp(daysAgo: 7, weightLbs: 180)
        let newer = ReflectionTestFixtures.bodyComp(daysAgo: 0, weightLbs: 180)
        let records = ReflectionSourceRecords(
            bodyCompositions: [older, newer],
            userProfile: ReflectionTestFixtures.profile()
        )
        let moment = try sut.moments(from: records)
            .first { $0.id == "checkin-\(newer.id)" }
        XCTAssertEqual(moment?.description, "You showed up. That's the hard part.")
    }

    func test_photoDataCarriedThrough() throws {
        let data = Data([0xFF, 0xD8])
        let bc = ReflectionTestFixtures.bodyComp(photo: data)
        let records = ReflectionSourceRecords(
            bodyCompositions: [bc],
            userProfile: ReflectionTestFixtures.profile()
        )
        XCTAssertEqual(try sut.moments(from: records).first?.photoData, data)
    }
}
