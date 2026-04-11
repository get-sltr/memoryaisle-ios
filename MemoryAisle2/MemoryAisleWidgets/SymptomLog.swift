import Foundation
import SwiftData

@Model
final class SymptomLog {
    var date: Date
    var nauseaLevel: Int // 0-5
    var appetiteLevel: Int // 0-5 (0 = no appetite, 5 = normal)
    var energyLevel: Int // 0-5
    var bloating: Bool
    var constipation: Bool
    var foodAversion: Bool
    var notes: String?

    init(
        date: Date = .now,
        nauseaLevel: Int = 0,
        appetiteLevel: Int = 3,
        energyLevel: Int = 3,
        bloating: Bool = false,
        constipation: Bool = false,
        foodAversion: Bool = false,
        notes: String? = nil
    ) {
        self.date = date
        self.nauseaLevel = nauseaLevel
        self.appetiteLevel = appetiteLevel
        self.energyLevel = energyLevel
        self.bloating = bloating
        self.constipation = constipation
        self.foodAversion = foodAversion
        self.notes = notes
    }
}
