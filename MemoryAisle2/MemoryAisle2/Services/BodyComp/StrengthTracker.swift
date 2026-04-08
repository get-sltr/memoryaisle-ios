import Combine
import Foundation
import SwiftData

@MainActor
final class StrengthTracker: ObservableObject {
    private let modelContext: ModelContext

    @Published var recentSessions: [TrainingSession] = []
    @Published var weeklyVolume: Int = 0
    @Published var strengthTrend: Trend = .stable

    enum Trend: String {
        case improving = "Improving"
        case maintaining = "Maintaining"
        case declining = "Declining"
        case stable = "Stable"
    }

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func refresh() {
        let fourWeeksAgo = Calendar.current.date(
            byAdding: .day, value: -28, to: .now
        ) ?? .now

        let predicate = #Predicate<TrainingSession> {
            $0.date >= fourWeeksAgo
        }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\.date)]
        recentSessions = (try? modelContext.fetch(descriptor)) ?? []

        computeWeeklyVolume()
        analyzeStrengthTrend()
    }

    func logSession(
        type: WorkoutType,
        durationMinutes: Int,
        intensity: WorkoutIntensity,
        muscleGroups: [MuscleGroup] = [],
        caloriesBurned: Double? = nil,
        notes: String? = nil
    ) {
        let session = TrainingSession(
            type: type,
            durationMinutes: durationMinutes,
            intensity: intensity,
            muscleGroups: muscleGroups,
            caloriesBurned: caloriesBurned,
            notes: notes
        )
        modelContext.insert(session)
        recentSessions.append(session)
        computeWeeklyVolume()
    }

    var isTrainingDay: Bool {
        let today = Calendar.current.startOfDay(for: .now)
        return recentSessions.contains {
            Calendar.current.isDate($0.date, inSameDayAs: today)
        }
    }

    var sessionsThisWeek: Int {
        let weekAgo = Calendar.current.date(
            byAdding: .day, value: -7, to: .now
        ) ?? .now
        return recentSessions.filter { $0.date >= weekAgo }.count
    }

    var strengthSessionsThisWeek: Int {
        let weekAgo = Calendar.current.date(
            byAdding: .day, value: -7, to: .now
        ) ?? .now
        return recentSessions.filter {
            $0.date >= weekAgo && $0.isStrengthTraining
        }.count
    }

    func proteinAdjustment() -> Double {
        let recentStrength = recentSessions.suffix(3)
        guard !recentStrength.isEmpty else { return 1.0 }

        let avgIntensity = recentStrength.reduce(0.0) { sum, session in
            sum + session.proteinMultiplier
        } / Double(recentStrength.count)

        return avgIntensity
    }

    private func computeWeeklyVolume() {
        let weekAgo = Calendar.current.date(
            byAdding: .day, value: -7, to: .now
        ) ?? .now

        weeklyVolume = recentSessions
            .filter { $0.date >= weekAgo }
            .reduce(0) { $0 + $1.durationMinutes }
    }

    private func analyzeStrengthTrend() {
        guard recentSessions.count >= 4 else {
            strengthTrend = .stable
            return
        }

        let midpoint = recentSessions.count / 2
        let firstHalf = Array(recentSessions.prefix(midpoint))
        let secondHalf = Array(recentSessions.suffix(midpoint))

        let firstAvgDuration = firstHalf.reduce(0) {
            $0 + $1.durationMinutes
        }
        let secondAvgDuration = secondHalf.reduce(0) {
            $0 + $1.durationMinutes
        }

        let firstFreq = Double(firstHalf.count) / 2.0
        let secondFreq = Double(secondHalf.count) / 2.0

        if secondAvgDuration > firstAvgDuration
            && secondFreq >= firstFreq {
            strengthTrend = .improving
        } else if secondAvgDuration < firstAvgDuration
            || secondFreq < firstFreq * 0.7 {
            strengthTrend = .declining
        } else {
            strengthTrend = .maintaining
        }
    }
}
