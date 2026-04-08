import Foundation
import SwiftData

@Model
final class TrainingSession {
    var id: String
    var date: Date
    var type: WorkoutType
    var durationMinutes: Int
    var intensity: WorkoutIntensity
    var muscleGroups: [MuscleGroup]
    var caloriesBurned: Double?
    var notes: String?
    var sourceIsHealthKit: Bool

    init(
        date: Date = .now,
        type: WorkoutType,
        durationMinutes: Int,
        intensity: WorkoutIntensity = .moderate,
        muscleGroups: [MuscleGroup] = [],
        caloriesBurned: Double? = nil,
        notes: String? = nil,
        sourceIsHealthKit: Bool = false
    ) {
        self.id = UUID().uuidString
        self.date = date
        self.type = type
        self.durationMinutes = durationMinutes
        self.intensity = intensity
        self.muscleGroups = muscleGroups
        self.caloriesBurned = caloriesBurned
        self.notes = notes
        self.sourceIsHealthKit = sourceIsHealthKit
    }

    var isStrengthTraining: Bool {
        type == .weights || type == .crossfit || type == .bodyweight
    }

    var proteinMultiplier: Double {
        switch (type, intensity) {
        case (.weights, .high), (.crossfit, .high):
            return 1.2
        case (.weights, .moderate), (.crossfit, .moderate):
            return 1.1
        case (.cardio, .high):
            return 1.05
        default:
            return 1.0
        }
    }
}

enum WorkoutType: String, Codable, CaseIterable {
    case weights = "Weights"
    case cardio = "Cardio"
    case crossfit = "CrossFit"
    case bodyweight = "Bodyweight"
    case yoga = "Yoga"
    case walking = "Walking"
    case hiit = "HIIT"
    case sports = "Sports"
}

enum WorkoutIntensity: String, Codable, CaseIterable {
    case light = "Light"
    case moderate = "Moderate"
    case high = "High"
}

enum MuscleGroup: String, Codable, CaseIterable {
    case chest = "Chest"
    case back = "Back"
    case shoulders = "Shoulders"
    case arms = "Arms"
    case legs = "Legs"
    case core = "Core"
    case fullBody = "Full Body"
}
