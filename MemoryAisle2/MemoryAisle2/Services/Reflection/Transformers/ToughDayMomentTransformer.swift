import Foundation

/// Detects "tough day" moments from symptom and nutrition signals. These
/// moments exist on purpose — the hard moments are part of the journey
/// too, and showing them back to the user makes the wins feel real. The
/// framing must always be validating, never clinical.
struct ToughDayMomentTransformer: MomentTransformer {

    private enum Trigger: Int, Comparable {
        case nausea = 0
        case lowCalories = 1
        case proteinMiss = 2

        static func < (lhs: Trigger, rhs: Trigger) -> Bool {
            lhs.rawValue < rhs.rawValue
        }

        var title: String {
            switch self {
            case .nausea: return "A tough day"
            case .lowCalories: return "Low fuel day"
            case .proteinMiss: return "A quieter stretch"
            }
        }

        var description: String {
            switch self {
            case .nausea: return "You pushed through. That counts."
            case .lowCalories: return "Some days the body just will not eat. You are still here."
            case .proteinMiss: return "A few softer days. And you are still here."
            }
        }
    }

    func moments(from records: ReflectionSourceRecords) throws -> [ReflectionMoment] {
        let target = records.userProfile?.proteinTargetGrams ?? 0
        let proteinThreshold = Double(target) * 0.7

        var triggersByDay: [Date: Trigger] = [:]

        // Nausea trigger: any symptom log with nauseaLevel >= 3
        for log in records.symptomLogs where log.nauseaLevel >= 3 {
            let day = Calendar.current.startOfDay(for: log.date)
            if let existing = triggersByDay[day] {
                triggersByDay[day] = min(existing, .nausea)
            } else {
                triggersByDay[day] = .nausea
            }
        }

        // Low calories trigger: any nutrition log with caloriesConsumed < 1200
        for log in records.nutritionLogs where log.caloriesConsumed < 1200 {
            let day = Calendar.current.startOfDay(for: log.date)
            let existing = triggersByDay[day]
            if existing == nil || existing! == .proteinMiss {
                triggersByDay[day] = .lowCalories
            }
        }

        // Three-day protein miss: emit on the third day of a run of misses
        let sortedLogs = records.nutritionLogs.sorted { $0.date < $1.date }
        var missStreak = 0
        for log in sortedLogs {
            if log.proteinGrams < proteinThreshold {
                missStreak += 1
                if missStreak >= 3 {
                    let day = Calendar.current.startOfDay(for: log.date)
                    if triggersByDay[day] == nil {
                        triggersByDay[day] = .proteinMiss
                    }
                }
            } else {
                missStreak = 0
            }
        }

        // Build moments
        let df = ISO8601DateFormatter()
        df.formatOptions = [.withInternetDateTime]

        return triggersByDay.map { (day, trigger) in
            ReflectionMoment(
                id: "toughDay-\(df.string(from: day))",
                date: day,
                type: .toughDay,
                category: .toughDay,
                title: trigger.title,
                description: trigger.description
            )
        }
        .sorted { $0.date > $1.date }
    }
}

