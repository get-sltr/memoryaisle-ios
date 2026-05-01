import XCTest
@testable import MemoryAisle2

/// Pins the load-bearing safety phrases in `MiraEngine.buildSystemPrompt`.
/// A regression here means a future edit silently removed a hard-line refusal
/// or the six-roles framing — both of which are review-gated text that
/// shouldn't drift. Update only with medical/legal sign-off.
@MainActor
final class MiraSystemPromptTests: XCTestCase {

    private func makePrompt() -> String {
        let profile = UserProfile(
            name: "Test",
            medication: .mounjaro,
            medicationModality: .injectable,
            productMode: .everyday,
            proteinTargetGrams: 130,
            calorieTarget: 1600
        )
        return MiraEngine.buildSystemPrompt(
            profile: profile,
            cyclePhase: .steadyState,
            giTriggers: [],
            pantryItems: []
        )
    }

    // MARK: - Six roles framing

    func test_promptDeclaresAllSixRoles() {
        let prompt = makePrompt()
        XCTAssertTrue(prompt.contains("GLP-1 medication expert"))
        XCTAssertTrue(prompt.contains("Side-effect triage"))
        XCTAssertTrue(prompt.contains("Medication-assistance"))
        XCTAssertTrue(prompt.contains("Nutrition advisor"))
        XCTAssertTrue(prompt.contains("Lean-mass preservation"))
        XCTAssertTrue(prompt.contains("Long-term lifestyle"))
    }

    // MARK: - Hard lines

    func test_promptDeclaresNeverPrescribe() {
        XCTAssertTrue(makePrompt().contains("Never prescribe"))
    }

    func test_promptDeclaresNeverAdminister() {
        XCTAssertTrue(makePrompt().contains("Never administer"))
    }

    func test_promptDeclaresNeverDistribute() {
        XCTAssertTrue(makePrompt().contains("Never distribute"))
    }

    func test_promptForbidsDoseChangeRecommendations() {
        let prompt = makePrompt()
        XCTAssertTrue(prompt.contains("Never recommend stopping, starting, increasing, or decreasing"))
    }

    func test_promptForbidsBrandNameReferences() {
        let prompt = makePrompt()
        XCTAssertTrue(prompt.contains("Never reference specific brand names"))
        // The prompt body itself must not leak the brand even though the
        // MedicationAnonymizer only sends class info — belt and suspenders.
        XCTAssertFalse(prompt.contains("Mounjaro"))
        XCTAssertFalse(prompt.contains("Ozempic"))
        XCTAssertFalse(prompt.contains("Wegovy"))
    }

    // MARK: - Refusal patterns

    func test_promptHandlesPretendDoctorJailbreak() {
        XCTAssertTrue(makePrompt().contains("Pretend you're my doctor"))
    }

    func test_promptHandlesHypotheticalDoseJailbreak() {
        XCTAssertTrue(makePrompt().contains("Should I take 1mg or 2mg"))
    }

    func test_promptHandlesSourcingJailbreak() {
        XCTAssertTrue(makePrompt().contains("buy compounded"))
    }

    func test_promptDirectsRefusalsTowardKindRedirect() {
        let prompt = makePrompt()
        XCTAssertTrue(prompt.contains("Always redirect kindly"))
        XCTAssertTrue(prompt.contains("never lecture"))
    }

    // MARK: - Factual reliability

    func test_promptRequiresLookupDrugFactForSpecificNumbers() {
        let prompt = makePrompt()
        XCTAssertTrue(prompt.contains("`lookupDrugFact`"))
        XCTAssertTrue(prompt.contains("Memory can drift"))
    }

    func test_promptForbidsFabricatingWhenToolReturnsNoData() {
        XCTAssertTrue(makePrompt().contains("Never fabricate"))
    }

    // MARK: - Safe Space carve-out

    func test_promptDeclaresSafeSpaceOffLimits() {
        XCTAssertTrue(makePrompt().contains("Safe Space"))
    }

    // MARK: - Privacy

    func test_promptForbidsReferencingUsersRealName() {
        XCTAssertTrue(makePrompt().contains("Never reference the user's real name"))
    }

    // MARK: - Care-team guardrails

    func test_promptForbidsPharmacyAndPrescriberSwitchAdvice() {
        let prompt = makePrompt()
        XCTAssertTrue(prompt.contains("Never recommend switching pharmacies or switching prescribers"))
    }

    func test_promptForbidsAdvertisingMedicationsBrandsOrPharmacies() {
        let prompt = makePrompt()
        XCTAssertTrue(prompt.contains("Never advertise, market, promote, or compare"))
    }

    func test_promptForbidsBridgingFromSymptomToDoseChange() {
        let prompt = makePrompt()
        XCTAssertTrue(prompt.contains("Never bridge from symptom to dose change"))
    }

    func test_promptDefaultsMedicationQuestionsToPrescriber() {
        let prompt = makePrompt()
        XCTAssertTrue(prompt.contains("DEFAULT FOR MEDICATION QUESTIONS"))
        XCTAssertTrue(prompt.contains("their prescriber is the right person for that"))
    }

    func test_promptHandlesPharmacySwitchJailbreak() {
        XCTAssertTrue(makePrompt().contains("Should I switch pharmacies"))
    }

    func test_promptHandlesMedComparisonJailbreak() {
        XCTAssertTrue(makePrompt().contains("Should I switch to a different GLP-1"))
    }

    func test_promptHandlesSymptomDangerJailbreak() {
        XCTAssertTrue(makePrompt().contains("Is this symptom dangerous"))
    }
}
