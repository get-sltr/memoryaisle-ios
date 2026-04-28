import XCTest
@testable import MemoryAisle2

/// Lifecycle invariants on the persisted job model. The orchestrator's resume
/// logic depends on these: misclassifying an in-flight job as terminal would
/// leave the user staring at a forever-spinning UI.
@MainActor
final class MealGenerationJobTests: XCTestCase {

    func test_newJob_isPendingAndNotTerminal() {
        let job = MealGenerationJob(firstDate: .now, totalDays: 7, trigger: .signup)
        XCTAssertEqual(job.status, .pending)
        XCTAssertTrue(job.isInFlight)
        XCTAssertFalse(job.isTerminal)
        XCTAssertFalse(job.isOrphaned())
    }

    func test_runningJob_isInFlight() {
        let job = MealGenerationJob(firstDate: .now, totalDays: 7, trigger: .signup)
        job.status = .running
        job.startedAt = .now
        XCTAssertTrue(job.isInFlight)
        XCTAssertFalse(job.isTerminal)
    }

    func test_completedJob_isTerminal_andNotOrphaned() {
        let job = MealGenerationJob(firstDate: .now, totalDays: 7, trigger: .signup)
        job.status = .completed
        job.completedAt = .now
        XCTAssertFalse(job.isInFlight)
        XCTAssertTrue(job.isTerminal)
        XCTAssertFalse(job.isOrphaned())
    }

    func test_runningJob_olderThanStaleWindow_isOrphaned() {
        let job = MealGenerationJob(firstDate: .now, totalDays: 7, trigger: .signup)
        job.status = .running
        job.startedAt = Date().addingTimeInterval(-600) // 10 min ago
        XCTAssertTrue(job.isOrphaned(staleAfter: 300))
    }

    func test_runningJob_youngerThanStaleWindow_isNotOrphaned() {
        let job = MealGenerationJob(firstDate: .now, totalDays: 7, trigger: .signup)
        job.status = .running
        job.startedAt = Date().addingTimeInterval(-30)
        XCTAssertFalse(job.isOrphaned(staleAfter: 300))
    }

    func test_pendingJob_isNeverOrphaned() {
        let job = MealGenerationJob(firstDate: .now, totalDays: 7, trigger: .signup)
        // Pending jobs haven't started yet; orphan-ness only applies to running.
        XCTAssertFalse(job.isOrphaned())
        XCTAssertFalse(job.isOrphaned(staleAfter: 0))
    }

    func test_partialAndFailedStatuses_areTerminal() {
        let partial = MealGenerationJob(firstDate: .now, totalDays: 7, trigger: .signup)
        partial.status = .partial
        XCTAssertTrue(partial.isTerminal)

        let failed = MealGenerationJob(firstDate: .now, totalDays: 7, trigger: .signup)
        failed.status = .failed
        XCTAssertTrue(failed.isTerminal)

        let cancelled = MealGenerationJob(firstDate: .now, totalDays: 7, trigger: .signup)
        cancelled.status = .cancelled
        XCTAssertTrue(cancelled.isTerminal)
    }
}
