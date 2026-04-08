import Foundation
import SwiftData

@Model
final class ProviderReport {
    var id: String
    var generatedAt: Date
    var startDate: Date
    var endDate: Date
    var avgProteinGrams: Double
    var proteinHitRate: Double
    var avgCalories: Double
    var avgWaterLiters: Double
    var weightStart: Double?
    var weightEnd: Double?
    var weightChange: Double?
    var leanMassChange: Double?
    var avgNauseaLevel: Double
    var avgEnergyLevel: Double
    var symptomDays: Int
    var trainingDays: Int
    var medicationAdherence: Double
    var mealPlanAdherence: Double
    var notesForProvider: String?
    var pdfData: Data?

    init(
        startDate: Date,
        endDate: Date,
        avgProteinGrams: Double = 0,
        proteinHitRate: Double = 0,
        avgCalories: Double = 0,
        avgWaterLiters: Double = 0
    ) {
        self.id = UUID().uuidString
        self.generatedAt = Date()
        self.startDate = startDate
        self.endDate = endDate
        self.avgProteinGrams = avgProteinGrams
        self.proteinHitRate = proteinHitRate
        self.avgCalories = avgCalories
        self.avgWaterLiters = avgWaterLiters
        self.avgNauseaLevel = 0
        self.avgEnergyLevel = 0
        self.symptomDays = 0
        self.trainingDays = 0
        self.medicationAdherence = 0
        self.mealPlanAdherence = 0
    }
}
