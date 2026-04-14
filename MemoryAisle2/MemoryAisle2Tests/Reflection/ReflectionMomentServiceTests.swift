import XCTest
@testable import MemoryAisle2

@MainActor
final class ReflectionMomentServiceTests: XCTestCase {

    func test_emptyRecords_returnsEmpty() {
        let service = ReflectionMomentService()
        let result = service.moments(for: .all, from: ReflectionSourceRecords())
        XCTAssertEqual(result, [])
    }

    func test_allFilter_mergesAllTransformerOutputs() {
        let service = ReflectionMomentService()
        let bc = ReflectionTestFixtures.bodyComp(daysAgo: 0)
        let session = ReflectionTestFixtures.session(daysAgo: 1)
        let records = ReflectionSourceRecords(
            bodyCompositions: [bc],
            trainingSessions: [session],
            userProfile: ReflectionTestFixtures.profile()
        )
        let result = service.moments(for: .all, from: records)
        XCTAssertTrue(result.contains { $0.type == .checkIn })
        XCTAssertTrue(result.contains { $0.type == .gym })
    }

    func test_sortedByDateDescending() {
        let service = ReflectionMomentService()
        let oldBC = ReflectionTestFixtures.bodyComp(daysAgo: 10)
        let newSession = ReflectionTestFixtures.session(daysAgo: 1)
        let records = ReflectionSourceRecords(
            bodyCompositions: [oldBC],
            trainingSessions: [newSession],
            userProfile: ReflectionTestFixtures.profile()
        )
        let result = service.moments(for: .all, from: records)
        XCTAssertGreaterThanOrEqual(result.count, 2)
        for i in 0..<(result.count - 1) {
            XCTAssertGreaterThanOrEqual(result[i].date, result[i + 1].date)
        }
    }

    func test_photosFilter_onlyPhotosSurvive() {
        let service = ReflectionMomentService()
        let withPhoto = ReflectionTestFixtures.bodyComp(daysAgo: 0, photo: Data([0xFF]))
        let withoutPhoto = ReflectionTestFixtures.bodyComp(daysAgo: 1, photo: nil)
        let session = ReflectionTestFixtures.session(daysAgo: 2)
        let records = ReflectionSourceRecords(
            bodyCompositions: [withPhoto, withoutPhoto],
            trainingSessions: [session],
            userProfile: ReflectionTestFixtures.profile()
        )
        let result = service.moments(for: .photos, from: records)
        for moment in result {
            XCTAssertNotNil(moment.photoData)
        }
        XCTAssertTrue(result.contains { $0.type == .checkIn })
    }

    func test_gymFilter_onlyGymTypeSurvives() {
        let service = ReflectionMomentService()
        let session = ReflectionTestFixtures.session(daysAgo: 0)
        let bc = ReflectionTestFixtures.bodyComp(daysAgo: 1)
        let records = ReflectionSourceRecords(
            bodyCompositions: [bc],
            trainingSessions: [session],
            userProfile: ReflectionTestFixtures.profile()
        )
        let result = service.moments(for: .gym, from: records)
        XCTAssertTrue(result.allSatisfy { $0.type == .gym })
    }

    func test_mealsFilter_emptyInV1() {
        let service = ReflectionMomentService()
        let bc = ReflectionTestFixtures.bodyComp(daysAgo: 0)
        let records = ReflectionSourceRecords(
            bodyCompositions: [bc],
            userProfile: ReflectionTestFixtures.profile()
        )
        XCTAssertEqual(service.moments(for: .meals, from: records), [])
    }

    func test_feelingsFilter_emptyInV1() {
        let service = ReflectionMomentService()
        let bc = ReflectionTestFixtures.bodyComp(daysAgo: 0)
        let records = ReflectionSourceRecords(
            bodyCompositions: [bc],
            userProfile: ReflectionTestFixtures.profile()
        )
        XCTAssertEqual(service.moments(for: .feelings, from: records), [])
    }

    func test_oneBrokenTransformer_othersStillRun() {
        struct BrokenTransformer: MomentTransformer {
            func moments(from records: ReflectionSourceRecords) throws -> [ReflectionMoment] {
                struct SomeError: Error {}
                throw SomeError()
            }
        }
        let service = ReflectionMomentService(
            transformers: [BrokenTransformer(), GymMomentTransformer()]
        )
        let session = ReflectionTestFixtures.session(daysAgo: 0)
        let records = ReflectionSourceRecords(trainingSessions: [session])
        let result = service.moments(for: .all, from: records)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].type, .gym)
    }
}
