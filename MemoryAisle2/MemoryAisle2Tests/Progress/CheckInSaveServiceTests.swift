import XCTest
import SwiftData
@testable import MemoryAisle2

@MainActor
final class CheckInSaveServiceTests: XCTestCase {

    private var context: ModelContext!
    private var container: ModelContainer!

    override func setUpWithError() throws {
        let schema = Schema([BodyComposition.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = container.mainContext
    }

    override func tearDownWithError() throws {
        context = nil
        container = nil
    }

    func test_save_createsBodyCompositionRecord() throws {
        let service = CheckInSaveService()
        try service.save(weight: 165.5, photoData: nil, in: context)

        let descriptor = FetchDescriptor<BodyComposition>()
        let records = try context.fetch(descriptor)

        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].weightLbs, 165.5)
        XCTAssertEqual(records[0].source, .manual)
        XCTAssertNil(records[0].photoData)
    }

    func test_save_persistsPhotoData() throws {
        let service = CheckInSaveService()
        let sampleJPEG = Data([0xFF, 0xD8, 0xFF, 0xE0])

        try service.save(weight: 160.0, photoData: sampleJPEG, in: context)

        let descriptor = FetchDescriptor<BodyComposition>()
        let records = try context.fetch(descriptor)

        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].photoData, sampleJPEG)
    }

    func test_save_usesManualSource() throws {
        let service = CheckInSaveService()
        try service.save(weight: 170.0, photoData: nil, in: context)

        let descriptor = FetchDescriptor<BodyComposition>()
        let records = try context.fetch(descriptor)

        XCTAssertEqual(records[0].source, .manual)
    }
}
