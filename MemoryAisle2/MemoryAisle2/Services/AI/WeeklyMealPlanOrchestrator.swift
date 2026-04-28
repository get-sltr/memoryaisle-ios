import Foundation
import OSLog
import SwiftData

/// Owns the lifecycle of a weekly meal plan generation. Persists a
/// `MealGenerationJob` so a kill-mid-generation can be detected and resumed.
/// Honors the feature flag and the per-trigger quota.
///
/// Callers should treat this as the only entry point for weekly generation —
/// don't call `MealGenerator.generateWeeklyPlan` directly from feature code,
/// because then the job won't get tracked and the quota won't be charged.
@MainActor
final class WeeklyMealPlanOrchestrator {
    private let generator: MealGenerator
    private let usage: WeeklyMealUsageGate
    private let flags: FeatureFlags
    private let logger = Logger(subsystem: "com.memoryaisle.MealGen", category: "Orchestrator")

    init(
        generator: MealGenerator = MealGenerator(),
        usage: WeeklyMealUsageGate = WeeklyMealUsageGate(),
        flags: FeatureFlags = FeatureFlags.shared
    ) {
        self.generator = generator
        self.usage = usage
        self.flags = flags
    }

    /// Reason a request was rejected before any Bedrock call was made.
    enum RejectionReason: String, Sendable {
        case featureFlagDisabled
        case quotaExhausted
        case alreadyInFlight
    }

    enum Outcome: Sendable {
        case launched(jobId: String)
        case rejected(RejectionReason)
    }

    // MARK: - Public entry

    /// Kick off a weekly generation. Idempotent: if an in-flight job exists for
    /// the same anchor date, returns `.alreadyInFlight` rather than stacking
    /// duplicate generation work.
    @discardableResult
    func startWeekly(
        profile: UserProfile,
        giTriggers: [String],
        pantryItems: [PantryItem],
        startDate: Date = .now,
        days: Int = 7,
        trigger: MealGenerationTrigger,
        isPro: Bool,
        context: ModelContext,
        onProgress: (@MainActor @Sendable (Int, Int) -> Void)? = nil,
        onCompleted: (@MainActor @Sendable (MealGenerationStatus) -> Void)? = nil
    ) -> Outcome {
        guard flags.weeklyMealPlanEnabled else {
            logger.info("Weekly gen rejected: feature flag off")
            return .rejected(.featureFlagDisabled)
        }

        if hasInFlightJob(for: startDate, in: context) {
            logger.info("Weekly gen rejected: already in-flight for \(startDate.ISO8601Format(), privacy: .public)")
            return .rejected(.alreadyInFlight)
        }

        if !usage.canStart(trigger: trigger, isPro: isPro, in: context) {
            logger.info("Weekly gen rejected: quota exhausted (trigger=\(trigger.rawValue, privacy: .public))")
            return .rejected(.quotaExhausted)
        }

        let job = MealGenerationJob(firstDate: startDate, totalDays: days, trigger: trigger)
        context.insert(job)
        usage.recordStart(trigger: trigger, in: context)
        let jobId = job.id

        Task { @MainActor in
            await self.run(
                job: job,
                profile: profile,
                giTriggers: giTriggers,
                pantryItems: pantryItems,
                days: days,
                startDate: startDate,
                context: context,
                onProgress: onProgress,
                onCompleted: onCompleted
            )
        }

        return .launched(jobId: jobId)
    }

    /// Sweep on app launch: any job marked `running` from a prior session is
    /// orphaned by the new launch and gets marked `failed` so the UI doesn't
    /// show a forever-spinning state.
    func reconcileOrphanedJobs(in context: ModelContext) {
        let descriptor = FetchDescriptor<MealGenerationJob>()
        guard let jobs = try? context.fetch(descriptor) else { return }
        for job in jobs where job.isOrphaned() {
            job.status = .failed
            job.completedAt = Date()
            job.lastError = "Interrupted by app termination"
            logger.warning("Reconciled orphan job \(job.id, privacy: .public)")
        }
    }

    // MARK: - Private

    private func run(
        job: MealGenerationJob,
        profile: UserProfile,
        giTriggers: [String],
        pantryItems: [PantryItem],
        days: Int,
        startDate: Date,
        context: ModelContext,
        onProgress: (@MainActor @Sendable (Int, Int) -> Void)?,
        onCompleted: (@MainActor @Sendable (MealGenerationStatus) -> Void)?
    ) async {
        job.status = .running
        job.startedAt = Date()

        let result = await generator.generateWeeklyPlan(
            profile: profile,
            giTriggers: giTriggers,
            pantryItems: pantryItems,
            days: days,
            startDate: startDate,
            onDayCompleted: { [weak job] _, outcome in
                guard let job else { return }
                switch outcome {
                case .success:
                    job.daysCompleted += 1
                case .failure(let error):
                    job.daysFailed += 1
                    job.lastError = error.localizedDescription
                }
                onProgress?(job.daysCompleted, job.totalDays)
            },
            context: context
        )

        let finalStatus: MealGenerationStatus
        if result.successCount == days {
            finalStatus = .completed
        } else if result.successCount == 0 {
            finalStatus = .failed
        } else {
            finalStatus = .partial
        }

        job.status = finalStatus
        job.completedAt = Date()
        logger.info("Job \(job.id, privacy: .public) finished status=\(finalStatus.rawValue, privacy: .public) success=\(result.successCount, privacy: .public) fail=\(result.failureCount, privacy: .public)")

        onCompleted?(finalStatus)
    }

    private func hasInFlightJob(for startDate: Date, in context: ModelContext) -> Bool {
        let anchor = Calendar.current.startOfDay(for: startDate)
        let descriptor = FetchDescriptor<MealGenerationJob>()
        guard let jobs = try? context.fetch(descriptor) else { return false }
        return jobs.contains { job in
            job.isInFlight && Calendar.current.isDate(job.firstDate, inSameDayAs: anchor)
        }
    }
}
