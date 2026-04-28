import XCTest
@testable import MemoryAisle2

/// Pins the empty-by-default contract on `CuratedDrugFacts`. A regression
/// where someone ships drug facts without legal/medical sign-off would fail
/// these — and that's the intent. Population requires updating
/// `docs/mira-intelligence-review.md` first.
@MainActor
final class CuratedDrugFactsTests: XCTestCase {

    func test_storeIsEmptyAtRest() {
        // Hard contract: drug facts ship empty until reviewed entries land.
        XCTAssertTrue(CuratedDrugFacts.entries.isEmpty,
                      "CuratedDrugFacts must remain empty until each entry passes medical/legal review.")
    }

    func test_lookupReturnsNilForAllClassesAndTopicsAtRest() {
        for drugClass in [DrugClass.semaglutide, .tirzepatide, .orforglipron, .unknown] {
            for topic in DrugFactTopic.allCases {
                XCTAssertNil(CuratedDrugFacts.lookup(drugClass: drugClass, topic: topic),
                             "Unexpected curated fact for \(drugClass) / \(topic.rawValue)")
            }
        }
    }

    // MARK: - Drug class mapping

    func test_drugClassFromMedication_mapsBrandsToClass() {
        XCTAssertEqual(DrugClass.from(medication: .ozempic), .semaglutide)
        XCTAssertEqual(DrugClass.from(medication: .wegovy), .semaglutide)
        XCTAssertEqual(DrugClass.from(medication: .rybelsus), .semaglutide)
        XCTAssertEqual(DrugClass.from(medication: .compoundedSemaglutide), .semaglutide)

        XCTAssertEqual(DrugClass.from(medication: .mounjaro), .tirzepatide)
        XCTAssertEqual(DrugClass.from(medication: .zepbound), .tirzepatide)
        XCTAssertEqual(DrugClass.from(medication: .compoundedTirzepatide), .tirzepatide)

        XCTAssertEqual(DrugClass.from(medication: .foundayo), .orforglipron)

        XCTAssertEqual(DrugClass.from(medication: .other), .unknown)
        XCTAssertEqual(DrugClass.from(medication: nil), .unknown)
    }
}
