import SwiftData
import XCTest
@testable import MemoryAisle2

/// Dispatch + behavior tests for the new Mira tools added in the intelligence
/// expansion: `lookupDrugFact`, `getRecentSymptoms`, `getMedicationPhaseSummary`,
/// `lookupMedicationProgram`, `lookupAppealTemplate`. Bedrock is not exercised
/// — these check the tool dispatcher contracts the lambda will call.
@MainActor
final class MiraToolExecutorNewToolsTests: XCTestCase {

    private var context: ModelContext!
    private var executor: MiraToolExecutor!

    override func setUp() {
        super.setUp()
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: UserProfile.self, NutritionLog.self, SymptomLog.self,
            PantryItem.self, GIToleranceRecord.self,
            configurations: config
        )
        context = ModelContext(container)
        executor = MiraToolExecutor(context: context)
    }

    // MARK: - lookupDrugFact

    func test_lookupDrugFact_unknownTopic_returnsHelpfulList() {
        let result = executor.execute(toolName: "lookupDrugFact", input: ["topic": "wat"])
        XCTAssertTrue(result.contains("I need a topic"))
        XCTAssertTrue(result.contains("sideEffectPrevalence"))
    }

    func test_lookupDrugFact_emptyStore_returnsDeferralNotFabrication() {
        // Curated store ships empty; no entry should exist for any topic yet.
        let result = executor.execute(
            toolName: "lookupDrugFact",
            input: ["topic": "halfLife"]
        )
        XCTAssertTrue(result.contains("don't have a verified number"))
        XCTAssertTrue(result.contains("FDA package insert"))
    }

    func test_lookupDrugFact_withProfile_anonymizesToDrugClass() {
        let profile = UserProfile(name: "T", medication: .mounjaro, medicationModality: .injectable)
        context.insert(profile)
        let result = executor.execute(
            toolName: "lookupDrugFact",
            input: ["topic": "warnings"]
        )
        // The deferral message references the topic but should not leak the
        // brand name (Mounjaro). Class is tirzepatide internally; we only
        // need to confirm the topic surfaced and brand didn't.
        XCTAssertTrue(result.contains("warnings"))
        XCTAssertFalse(result.contains("Mounjaro"))
    }

    // MARK: - getRecentSymptoms

    func test_getRecentSymptoms_emptyStore_returnsCleanZeroState() {
        let result = executor.execute(toolName: "getRecentSymptoms", input: [:])
        XCTAssertTrue(result.contains("No symptoms logged"))
    }

    func test_getRecentSymptoms_summarizesIntoBands() {
        // Three days of nausea-3 entries → moderate-to-severe band.
        for offset in 0..<3 {
            let date = Calendar.current.date(byAdding: .day, value: -offset, to: .now) ?? .now
            let log = SymptomLog(
                date: date,
                nauseaLevel: 3,
                appetiteLevel: 1,
                energyLevel: 1
            )
            context.insert(log)
        }
        let result = executor.execute(toolName: "getRecentSymptoms", input: [:])
        XCTAssertTrue(result.contains("3 entries"))
        XCTAssertTrue(result.contains("moderate to severe"))
        XCTAssertTrue(result.contains("very low") || result.contains("low"))
    }

    // MARK: - getMedicationPhaseSummary

    func test_phaseSummary_noProfile_returnsCleanFallback() {
        let result = executor.execute(toolName: "getMedicationPhaseSummary", input: [:])
        XCTAssertTrue(result.contains("No user profile"))
    }

    func test_phaseSummary_oralUser_returnsNonInjectionMessage() {
        let profile = UserProfile(name: "T", medication: .rybelsus, medicationModality: .oralWithFasting)
        context.insert(profile)
        let result = executor.execute(toolName: "getMedicationPhaseSummary", input: [:])
        XCTAssertTrue(result.contains("isn't on an injection schedule"))
    }

    func test_phaseSummary_injectionUser_returnsCyclePhase() {
        let profile = UserProfile(name: "T", medication: .mounjaro, medicationModality: .injectable)
        profile.injectionDay = 4 // Wednesday
        context.insert(profile)
        let result = executor.execute(toolName: "getMedicationPhaseSummary", input: [:])
        XCTAssertTrue(result.contains("Cycle phase:"))
        XCTAssertTrue(result.contains("Strategy:"))
        XCTAssertTrue(result.contains("Appetite expected:"))
    }

    // MARK: - lookupMedicationProgram (scaffold)

    func test_lookupMedicationProgram_returnsDeferral() {
        let result = executor.execute(
            toolName: "lookupMedicationProgram",
            input: ["drugClass": "tirzepatide"]
        )
        XCTAssertTrue(result.contains("don't have a curated assistance-program list"))
        XCTAssertTrue(result.contains("manufacturer's support line"))
    }

    func test_lookupMedicationProgram_missingClass_stillSafe() {
        let result = executor.execute(toolName: "lookupMedicationProgram", input: [:])
        XCTAssertTrue(result.contains("this medication"))
    }

    // MARK: - lookupAppealTemplate (scaffold)

    func test_lookupAppealTemplate_returnsDeferral() {
        let result = executor.execute(
            toolName: "lookupAppealTemplate",
            input: ["category": "medical_necessity"]
        )
        XCTAssertTrue(result.contains("don't have a verified appeal template"))
        XCTAssertTrue(result.contains("medical_necessity"))
    }

    // MARK: - Unknown tool fallthrough

    func test_unknownTool_returnsExplicitError() {
        let result = executor.execute(toolName: "nope", input: [:])
        XCTAssertTrue(result.contains("Unknown tool"))
    }
}
