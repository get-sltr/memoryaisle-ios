import SwiftData
import XCTest
@testable import MemoryAisle2

/// Quota policy enforcement. Free users can hit a real cost ceiling if these
/// rules drift; Pro users expect "no waiting" so a regression that gates a
/// Pro user looks like a billing bug. Pin every branch.
@MainActor
final class WeeklyMealUsageGateTests: XCTestCase {

    private var defaults: UserDefaults!
    private var gate: WeeklyMealUsageGate!
    private var context: ModelContext!

    override func setUp() {
        super.setUp()
        // Isolate state from other tests by using an in-memory suite.
        let suite = "WeeklyMealUsageGateTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
        gate = WeeklyMealUsageGate(defaults: defaults)

        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: MealGenerationJob.self, configurations: config)
        context = ModelContext(container)
    }

    // MARK: - Signup

    func test_signup_isAllowedOnFirstCall() {
        XCTAssertTrue(gate.canStart(trigger: .signup, isPro: false, in: context))
    }

    func test_signup_isRejectedAfterRecording() {
        gate.recordStart(trigger: .signup, in: context)
        XCTAssertFalse(gate.canStart(trigger: .signup, isPro: false, in: context))
        // Pro doesn't override; signup is once per lifetime.
        XCTAssertFalse(gate.canStart(trigger: .signup, isPro: true, in: context))
    }

    // MARK: - Backfill

    func test_backfill_isAllowedWhenNeverRun() {
        XCTAssertTrue(gate.canStart(trigger: .backfill, isPro: false, in: context))
    }

    func test_backfill_isRejectedDuringCooldown() {
        gate.recordStart(trigger: .backfill, in: context)
        XCTAssertFalse(gate.canStart(trigger: .backfill, isPro: false, in: context))
    }

    func test_backfill_allowedAfterCooldownElapses() {
        // Pre-seed an old timestamp older than cooldown.
        let old = Date().addingTimeInterval(-(gate.backfillCooldown + 60))
        defaults.set(old, forKey: "weeklyGen.lastBackfillAt")
        XCTAssertTrue(gate.canStart(trigger: .backfill, isPro: false, in: context))
    }

    // MARK: - Manual

    func test_manual_proUser_alwaysAllowed() {
        XCTAssertTrue(gate.canStart(trigger: .manual, isPro: true, in: context))
        gate.recordStart(trigger: .manual, in: context)
        XCTAssertTrue(gate.canStart(trigger: .manual, isPro: true, in: context))
    }

    func test_manual_freeUser_rejectedDuringCooldown() {
        gate.recordStart(trigger: .manual, in: context)
        XCTAssertFalse(gate.canStart(trigger: .manual, isPro: false, in: context))
    }

    func test_manual_freeUser_allowedAfterCooldown() {
        let old = Date().addingTimeInterval(-(gate.freeManualCooldown + 60))
        defaults.set(old, forKey: "weeklyGen.lastFreeManualAt")
        XCTAssertTrue(gate.canStart(trigger: .manual, isPro: false, in: context))
    }
}
