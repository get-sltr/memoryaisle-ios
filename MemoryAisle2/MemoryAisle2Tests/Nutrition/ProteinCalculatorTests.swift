import XCTest
@testable import MemoryAisle2

/// ProteinCalculator tests. Wrong protein targets directly drive wrong
/// user guidance, so every edge case here is a hard boundary: zero /
/// negative weight, out-of-range body fat, extreme training levels,
/// and the cycle-phase multiplier. The suite also enforces the safety
/// floor so the calculator can never return a zero or negative target.
@MainActor
final class ProteinCalculatorTests: XCTestCase {

    // MARK: - Baseline

    func test_standardUser_180lb_25bf_lifts_producesExpectedTarget() {
        let input = ProteinCalculator.Input(
            bodyWeightLbs: 180,
            bodyFatPercentage: 25,
            trainingLevel: .lifts,
            cyclePhase: nil
        )
        let result = ProteinCalculator.calculate(input: input)

        XCTAssertEqual(result.leanMassLbs, 135, accuracy: 0.01)
        XCTAssertEqual(result.gramsPerLbLeanMass, 1.2, accuracy: 0.001)
        XCTAssertEqual(result.dailyTargetGrams, 162)
        XCTAssertEqual(result.perMealTargetGrams, 40)
    }

    func test_missingBodyFat_assumesConservativeDefault() {
        // 180 lb, unknown BF → falls back to ~25% BF default.
        // Must not crash and must produce the same lean mass as the
        // explicit 25% case.
        let input = ProteinCalculator.Input(
            bodyWeightLbs: 180,
            bodyFatPercentage: nil,
            trainingLevel: .lifts,
            cyclePhase: nil
        )
        let result = ProteinCalculator.calculate(input: input)

        XCTAssertEqual(result.leanMassLbs, 135, accuracy: 0.01)
        XCTAssertEqual(result.dailyTargetGrams, 162)
    }

    // MARK: - Training level

    func test_trainingLevel_cardio_lowerMultiplier() {
        let input = ProteinCalculator.Input(
            bodyWeightLbs: 180,
            bodyFatPercentage: 25,
            trainingLevel: .cardio,
            cyclePhase: nil
        )
        let result = ProteinCalculator.calculate(input: input)

        XCTAssertEqual(result.gramsPerLbLeanMass, 1.0, accuracy: 0.001)
        XCTAssertEqual(result.dailyTargetGrams, 135)
    }

    func test_trainingLevel_none_stillMeetsFloor() {
        // Small person, no training → 0.8x multiplier could produce a
        // very low target. The calculator must enforce a safety floor.
        let input = ProteinCalculator.Input(
            bodyWeightLbs: 100,
            bodyFatPercentage: 30,
            trainingLevel: .none,
            cyclePhase: nil
        )
        let result = ProteinCalculator.calculate(input: input)

        XCTAssertGreaterThanOrEqual(result.dailyTargetGrams, ProteinCalculator.minimumDailyTargetGrams)
    }

    // MARK: - Cycle phase

    func test_appetiteReturn_boostsTargetByFivePercent() {
        let base = ProteinCalculator.calculate(input: .init(
            bodyWeightLbs: 180,
            bodyFatPercentage: 25,
            trainingLevel: .lifts,
            cyclePhase: nil
        ))
        let boosted = ProteinCalculator.calculate(input: .init(
            bodyWeightLbs: 180,
            bodyFatPercentage: 25,
            trainingLevel: .lifts,
            cyclePhase: .appetiteReturn
        ))

        // 162 * 1.05 = 170.1 → rounded 170
        XCTAssertEqual(boosted.dailyTargetGrams, 170)
        XCTAssertGreaterThan(boosted.dailyTargetGrams, base.dailyTargetGrams)
    }

    func test_peakSuppression_noBoost() {
        let base = ProteinCalculator.calculate(input: .init(
            bodyWeightLbs: 180,
            bodyFatPercentage: 25,
            trainingLevel: .lifts,
            cyclePhase: nil
        ))
        let peak = ProteinCalculator.calculate(input: .init(
            bodyWeightLbs: 180,
            bodyFatPercentage: 25,
            trainingLevel: .lifts,
            cyclePhase: .peakSuppression
        ))

        XCTAssertEqual(peak.dailyTargetGrams, base.dailyTargetGrams)
    }

    // MARK: - Safety boundaries

    func test_zeroWeight_returnsSafetyFloor() {
        let input = ProteinCalculator.Input(
            bodyWeightLbs: 0,
            bodyFatPercentage: 25,
            trainingLevel: .lifts,
            cyclePhase: nil
        )
        let result = ProteinCalculator.calculate(input: input)

        XCTAssertGreaterThanOrEqual(result.leanMassLbs, 0)
        XCTAssertEqual(result.dailyTargetGrams, ProteinCalculator.minimumDailyTargetGrams)
        XCTAssertGreaterThan(result.perMealTargetGrams, 0)
    }

    func test_negativeWeight_returnsSafetyFloor() {
        let input = ProteinCalculator.Input(
            bodyWeightLbs: -50,
            bodyFatPercentage: 25,
            trainingLevel: .lifts,
            cyclePhase: nil
        )
        let result = ProteinCalculator.calculate(input: input)

        XCTAssertGreaterThanOrEqual(result.leanMassLbs, 0)
        XCTAssertEqual(result.dailyTargetGrams, ProteinCalculator.minimumDailyTargetGrams)
    }

    func test_bodyFatAbove100_clampedAndReturnsFloor() {
        // Impossible value — likely a user typing into the wrong field.
        // Must not produce a negative lean mass or a zero target.
        let input = ProteinCalculator.Input(
            bodyWeightLbs: 180,
            bodyFatPercentage: 140,
            trainingLevel: .lifts,
            cyclePhase: nil
        )
        let result = ProteinCalculator.calculate(input: input)

        XCTAssertGreaterThanOrEqual(result.leanMassLbs, 0)
        XCTAssertGreaterThanOrEqual(result.dailyTargetGrams, ProteinCalculator.minimumDailyTargetGrams)
    }

    func test_negativeBodyFat_clampedToZero() {
        // A negative BF input should be clamped to 0 (treat body as
        // 100% lean), not inflate lean mass above body weight.
        let input = ProteinCalculator.Input(
            bodyWeightLbs: 180,
            bodyFatPercentage: -10,
            trainingLevel: .lifts,
            cyclePhase: nil
        )
        let result = ProteinCalculator.calculate(input: input)

        XCTAssertLessThanOrEqual(result.leanMassLbs, 180)
        XCTAssertGreaterThanOrEqual(result.leanMassLbs, 0)
    }

    func test_extremelyHighBodyFat_stillReturnsFloor() {
        // 180 lb with 95% BF clamps to the upper range and still hits
        // the safety floor.
        let input = ProteinCalculator.Input(
            bodyWeightLbs: 180,
            bodyFatPercentage: 95,
            trainingLevel: .lifts,
            cyclePhase: nil
        )
        let result = ProteinCalculator.calculate(input: input)

        XCTAssertGreaterThanOrEqual(result.dailyTargetGrams, ProteinCalculator.minimumDailyTargetGrams)
        XCTAssertGreaterThanOrEqual(result.leanMassLbs, 0)
    }

    // MARK: - Per-meal split

    func test_perMealTargetAlwaysPositive() {
        // With a zero weight input the safety floor kicks in and the
        // per-meal target must still be greater than zero.
        let input = ProteinCalculator.Input(
            bodyWeightLbs: 0,
            bodyFatPercentage: nil,
            trainingLevel: .none,
            cyclePhase: nil
        )
        let result = ProteinCalculator.calculate(input: input)
        XCTAssertGreaterThan(result.perMealTargetGrams, 0)
    }
}
