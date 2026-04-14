import XCTest
@testable import MemoryAisle2

@MainActor
final class HeroPhotosServiceTests: XCTestCase {

    private let sut = HeroPhotosService()

    func test_noRecords_returnsNilTuple() {
        let records = ReflectionSourceRecords()
        let photos = sut.photos(from: records)
        XCTAssertNil(photos.day1)
        XCTAssertNil(photos.today)
    }

    func test_singleRecordWithPhoto_returnsSameForBoth() {
        let data = Data([0xFF, 0xD8])
        let bc = ReflectionTestFixtures.bodyComp(daysAgo: 0, photo: data)
        let records = ReflectionSourceRecords(bodyCompositions: [bc])
        let photos = sut.photos(from: records)
        XCTAssertEqual(photos.day1, data)
        XCTAssertEqual(photos.today, data)
    }

    func test_multipleRecords_returnsEarliestAndLatest() {
        let old = Data([0xAA])
        let new = Data([0xBB])
        let older = ReflectionTestFixtures.bodyComp(daysAgo: 30, photo: old)
        let newer = ReflectionTestFixtures.bodyComp(daysAgo: 0, photo: new)
        let records = ReflectionSourceRecords(bodyCompositions: [newer, older])
        let photos = sut.photos(from: records)
        XCTAssertEqual(photos.day1, old)
        XCTAssertEqual(photos.today, new)
    }

    func test_recordsWithoutPhotoDataIgnored() {
        let data = Data([0xCC])
        let withoutPhoto = ReflectionTestFixtures.bodyComp(daysAgo: 30, photo: nil)
        let withPhoto = ReflectionTestFixtures.bodyComp(daysAgo: 0, photo: data)
        let records = ReflectionSourceRecords(bodyCompositions: [withoutPhoto, withPhoto])
        let photos = sut.photos(from: records)
        XCTAssertEqual(photos.day1, data)
        XCTAssertEqual(photos.today, data)
    }
}
