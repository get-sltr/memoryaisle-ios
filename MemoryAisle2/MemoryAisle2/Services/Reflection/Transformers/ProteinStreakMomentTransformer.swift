import Foundation

/// Computes consecutive-day protein streaks from NutritionLog records and
/// emits milestone moments at each crossed threshold (7, 14, 30, 60, 90,
/// 180 days). A user who hits 7, breaks, then hits 7 again gets two
/// moments (one per streak ending).
struct ProteinStreakMomentTransformer: MomentTransformer {

    private struct Threshold {
        let days: Int
        let title: String
        let description: String
    }

    private let thresholds: [Threshold] = [
        Threshold(days: 7, title: "7 days of protein", description: "Your muscles are listening."),
        Threshold(days: 14, title: "Two weeks strong", description: "You are making this part automatic."),
        Threshold(days: 30, title: "A whole month", description: "30 days of fueling yourself right."),
        Threshold(days: 60, title: "60 days unshakeable", description: "This is who you are now."),
        Threshold(days: 90, title: "90 days", description: "The rhythm is real."),
        Threshold(days: 180, title: "Six months", description: "Half a year of showing up for yourself.")
    ]

    func moments(from records: ReflectionSourceRecords) throws -> [ReflectionMoment] {
        guard let target = records.userProfile?.proteinTargetGrams, target > 0 else {
            return []
        }

        let sortedLogs = records.nutritionLogs.sorted { $0.date < $1.date }
        let streaks = computeStreaks(logs: sortedLogs, target: Double(target))

        var result: [ReflectionMoment] = []
        for streak in streaks {
            for threshold in thresholds where streak.length >= threshold.days {
                result.append(
                    ReflectionMoment(
                        id: "proteinStreak-\(threshold.days)-\(streak.endDateISO)",
                        date: streak.endDate,
                        type: .proteinStreak,
                        category: .milestone,
                        title: threshold.title,
                        description: threshold.description
                    )
                )
            }
        }
        return result
    }

    private struct Streak {
        let length: Int
        let endDate: Date
        var endDateISO: String {
            let df = ISO8601DateFormatter()
            df.formatOptions = [.withInternetDateTime]
            return df.string(from: endDate)
        }
    }

    private func computeStreaks(logs: [NutritionLog], target: Double) -> [Streak] {
        guard !logs.isEmpty else { return [] }

        var streaks: [Streak] = []
        var currentLength = 0
        var currentEnd: Date?
        var previousDate: Date?

        for log in logs {
            let hit = log.proteinGrams >= target
            let consecutive = previousDate.map {
                Calendar.current.dateComponents([.day], from: $0, to: log.date).day == 1
            } ?? true

            if hit && consecutive {
                currentLength += 1
                currentEnd = log.date
            } else if hit {
                if let end = currentEnd, currentLength >= 7 {
                    streaks.append(Streak(length: currentLength, endDate: end))
                }
                currentLength = 1
                currentEnd = log.date
            } else {
                if let end = currentEnd, currentLength >= 7 {
                    streaks.append(Streak(length: currentLength, endDate: end))
                }
                currentLength = 0
                currentEnd = nil
            }
            previousDate = log.date
        }

        if let end = currentEnd, currentLength >= 7 {
            streaks.append(Streak(length: currentLength, endDate: end))
        }

        return streaks
    }
}
