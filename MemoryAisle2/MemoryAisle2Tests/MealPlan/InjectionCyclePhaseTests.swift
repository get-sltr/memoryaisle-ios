import XCTest
@testable import MemoryAisle2

/// Per-day phase computation. The weekly meal generator passes each future
/// day's phase to Mira so meal style adapts (high-protein days vs gentle
/// post-injection days). Wrong phase produces wrong portion size at the wrong time.
@MainActor
final class InjectionCyclePhaseTests: XCTestCase {

    // Sunday=1, Monday=2, ..., Saturday=7 in Calendar.weekday

    private func date(weekday: Int) -> Date {
        // Anchor on a known Sunday (2026-04-26 was a Sunday) and offset.
        var components = DateComponents()
        components.year = 2026
        components.month = 4
        components.day = 26 + (weekday - 1)
        components.hour = 12
        return Calendar(identifier: .gregorian).date(from: components)!
    }

    func test_dayOfInjection_isInjectionDayPhase() {
        // Injection day is Wednesday (4); test on a Wednesday.
        let phase = InjectionCycleEngine.phase(forDate: date(weekday: 4), injectionDay: 4)
        XCTAssertEqual(phase, .injectionDay)
    }

    func test_oneAndTwoDaysAfter_arePeakSuppression() {
        let one = InjectionCycleEngine.phase(forDate: date(weekday: 5), injectionDay: 4)
        let two = InjectionCycleEngine.phase(forDate: date(weekday: 6), injectionDay: 4)
        XCTAssertEqual(one, .peakSuppression)
        XCTAssertEqual(two, .peakSuppression)
    }

    func test_threeAndFourDaysAfter_areSteadyState() {
        let three = InjectionCycleEngine.phase(forDate: date(weekday: 7), injectionDay: 4)
        let four = InjectionCycleEngine.phase(forDate: date(weekday: 1), injectionDay: 4)
        XCTAssertEqual(three, .steadyState)
        XCTAssertEqual(four, .steadyState)
    }

    func test_fiveDaysAfter_isAppetiteReturn() {
        let phase = InjectionCycleEngine.phase(forDate: date(weekday: 2), injectionDay: 4)
        XCTAssertEqual(phase, .appetiteReturn)
    }

    func test_sixDaysAfter_isPreInjection() {
        let phase = InjectionCycleEngine.phase(forDate: date(weekday: 3), injectionDay: 4)
        XCTAssertEqual(phase, .preInjection)
    }

    func test_phasesShiftCorrectlyAcrossSevenConsecutiveDays() {
        // Walk forward seven days starting on injection day; verify the
        // phases progress monotonically through the cycle.
        let injectionDay = 4 // Wednesday
        var phases: [CyclePhase] = []
        for offset in 0..<7 {
            let weekday = ((injectionDay - 1 + offset) % 7) + 1
            phases.append(InjectionCycleEngine.phase(forDate: date(weekday: weekday), injectionDay: injectionDay))
        }
        XCTAssertEqual(phases, [
            .injectionDay,
            .peakSuppression,
            .peakSuppression,
            .steadyState,
            .steadyState,
            .appetiteReturn,
            .preInjection
        ])
    }
}
