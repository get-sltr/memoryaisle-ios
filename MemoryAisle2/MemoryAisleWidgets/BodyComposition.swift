import Foundation
import SwiftData

@Model
final class BodyComposition {
    var id: String
    var date: Date
    var weightLbs: Double
    var bodyFatPercent: Double?
    var leanMassLbs: Double?
    var waistInches: Double?
    var source: BodyCompSource
    var photoData: Data?

    init(
        date: Date = .now,
        weightLbs: Double,
        bodyFatPercent: Double? = nil,
        leanMassLbs: Double? = nil,
        waistInches: Double? = nil,
        source: BodyCompSource = .manual,
        photoData: Data? = nil
    ) {
        self.id = UUID().uuidString
        self.date = date
        self.weightLbs = weightLbs
        self.bodyFatPercent = bodyFatPercent
        self.leanMassLbs = leanMassLbs
        self.waistInches = waistInches
        self.source = source
        self.photoData = photoData
    }

    var computedLeanMass: Double {
        if let lm = leanMassLbs { return lm }
        if let bf = bodyFatPercent {
            return weightLbs * (1 - bf / 100)
        }
        return weightLbs * 0.75
    }

    var computedFatMass: Double {
        weightLbs - computedLeanMass
    }
}

enum BodyCompSource: String, Codable {
    case manual = "Manual"
    case healthKit = "HealthKit"
    case dexa = "DEXA"
    case smartScale = "Smart Scale"
}
