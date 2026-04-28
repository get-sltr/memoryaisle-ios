import Foundation
import SwiftData

/// Persisted record of a weekly-meal-plan generation. Survives app kill so a
/// generation interrupted mid-flight can be resumed on next launch instead of
/// leaving the user with a half-built week and no signal.
@Model
final class MealGenerationJob {
    var id: String
    var requestedAt: Date
    var startedAt: Date?
    var completedAt: Date?
    var status: MealGenerationStatus
    var firstDate: Date
    var totalDays: Int
    var daysCompleted: Int
    var daysFailed: Int
    var lastError: String?
    /// Trigger that produced this job — distinguishes signup auto-gen from
    /// backfill, manual regen, etc., so the orchestrator can apply the right
    /// quota/flag policy.
    var trigger: MealGenerationTrigger

    init(
        firstDate: Date,
        totalDays: Int,
        trigger: MealGenerationTrigger
    ) {
        self.id = UUID().uuidString
        self.requestedAt = Date()
        self.status = .pending
        self.firstDate = Calendar.current.startOfDay(for: firstDate)
        self.totalDays = totalDays
        self.daysCompleted = 0
        self.daysFailed = 0
        self.trigger = trigger
    }

    var isTerminal: Bool {
        status == .completed || status == .partial || status == .failed || status == .cancelled
    }

    var isInFlight: Bool {
        status == .pending || status == .running
    }

    /// True when the job was started but never reported completion. Likely the
    /// app was killed before the generator finished — caller should resume.
    func isOrphaned(staleAfter seconds: TimeInterval = 300) -> Bool {
        guard status == .running, let startedAt else { return false }
        return Date().timeIntervalSince(startedAt) > seconds
    }
}

enum MealGenerationStatus: String, Codable, Sendable {
    case pending
    case running
    case completed
    case partial
    case failed
    case cancelled
}

enum MealGenerationTrigger: String, Codable, Sendable {
    case signup
    case backfill
    case manual
}
