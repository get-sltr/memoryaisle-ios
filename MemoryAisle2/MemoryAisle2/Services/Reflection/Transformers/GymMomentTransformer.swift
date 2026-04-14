import Foundation

/// Transforms TrainingSession records into gym moments. One moment per
/// session — a user who trains five times a week gets five celebrations
/// that week, and that's the point.
struct GymMomentTransformer: MomentTransformer {

    func moments(from records: ReflectionSourceRecords) throws -> [ReflectionMoment] {
        records.trainingSessions.map { session in
            ReflectionMoment(
                id: "gym-\(session.id)",
                date: session.date,
                type: .gym,
                category: .standard,
                title: title(for: session.type),
                description: "\(session.durationMinutes) min · \(session.intensity.rawValue)",
                metadataLabel: metadataLabel(for: session)
            )
        }
    }

    private func title(for type: WorkoutType) -> String {
        switch type {
        case .weights:    return "Weights day"
        case .cardio:     return "Cardio session"
        case .crossfit:   return "CrossFit"
        case .bodyweight: return "Bodyweight"
        case .yoga:       return "Yoga"
        case .walking:    return "Walk"
        case .hiit:       return "HIIT"
        case .sports:     return "Sports"
        }
    }

    private func metadataLabel(for session: TrainingSession) -> String? {
        guard session.isStrengthTraining, !session.muscleGroups.isEmpty else {
            return nil
        }
        return session.muscleGroups
            .map { $0.rawValue.uppercased() }
            .joined(separator: " + ")
    }
}
