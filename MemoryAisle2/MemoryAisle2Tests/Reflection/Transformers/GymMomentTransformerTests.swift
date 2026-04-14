import XCTest
@testable import MemoryAisle2

@MainActor
final class GymMomentTransformerTests: XCTestCase {

    private let sut = GymMomentTransformer()

    func test_noSessions_returnsEmpty() throws {
        let records = ReflectionSourceRecords()
        XCTAssertEqual(try sut.moments(from: records), [])
    }

    func test_oneSession_producesOneMoment() throws {
        let session = ReflectionTestFixtures.session(type: .weights)
        let records = ReflectionSourceRecords(trainingSessions: [session])
        let result = try sut.moments(from: records)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].type, .gym)
    }

    func test_weightsTitle() throws {
        let session = ReflectionTestFixtures.session(type: .weights)
        let records = ReflectionSourceRecords(trainingSessions: [session])
        XCTAssertEqual(try sut.moments(from: records).first?.title, "Weights day")
    }

    func test_cardioTitle() throws {
        let session = ReflectionTestFixtures.session(type: .cardio)
        let records = ReflectionSourceRecords(trainingSessions: [session])
        XCTAssertEqual(try sut.moments(from: records).first?.title, "Cardio session")
    }

    func test_yogaTitle() throws {
        let session = ReflectionTestFixtures.session(type: .yoga)
        let records = ReflectionSourceRecords(trainingSessions: [session])
        XCTAssertEqual(try sut.moments(from: records).first?.title, "Yoga")
    }

    func test_descriptionFormatsDurationAndIntensity() throws {
        let session = ReflectionTestFixtures.session(duration: 45, intensity: .high)
        let records = ReflectionSourceRecords(trainingSessions: [session])
        XCTAssertEqual(try sut.moments(from: records).first?.description, "45 min · High")
    }

    func test_strengthSessionHasMuscleMetadata() throws {
        let session = ReflectionTestFixtures.session(type: .weights, muscles: [.legs])
        let records = ReflectionSourceRecords(trainingSessions: [session])
        XCTAssertEqual(try sut.moments(from: records).first?.metadataLabel, "LEGS")
    }

    func test_strengthMultipleMusclesJoined() throws {
        let session = ReflectionTestFixtures.session(type: .weights, muscles: [.chest, .back])
        let records = ReflectionSourceRecords(trainingSessions: [session])
        XCTAssertEqual(try sut.moments(from: records).first?.metadataLabel, "CHEST + BACK")
    }

    func test_cardioHasNoMuscleMetadata() throws {
        let session = ReflectionTestFixtures.session(type: .cardio, muscles: [])
        let records = ReflectionSourceRecords(trainingSessions: [session])
        XCTAssertNil(try sut.moments(from: records).first?.metadataLabel)
    }
}
