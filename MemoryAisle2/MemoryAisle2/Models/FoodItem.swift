import Foundation
import SwiftData

@Model
final class FoodItem {
    var id: String
    var name: String
    var brand: String?
    var barcode: String?
    var servingSizeGrams: Double
    var proteinGrams: Double
    var caloriesPerServing: Double
    var carbsGrams: Double
    var fatGrams: Double
    var fiberGrams: Double
    var sugarGrams: Double
    var sodiumMg: Double
    var isNauseaSafe: Bool
    var giRisk: GIRiskLevel
    var scannedAt: Date
    var source: FoodSource

    init(
        name: String,
        brand: String? = nil,
        barcode: String? = nil,
        servingSizeGrams: Double = 100,
        proteinGrams: Double = 0,
        caloriesPerServing: Double = 0,
        carbsGrams: Double = 0,
        fatGrams: Double = 0,
        fiberGrams: Double = 0,
        sugarGrams: Double = 0,
        sodiumMg: Double = 0,
        isNauseaSafe: Bool = true,
        giRisk: GIRiskLevel = .low,
        source: FoodSource = .manual
    ) {
        self.id = UUID().uuidString
        self.name = name
        self.brand = brand
        self.barcode = barcode
        self.servingSizeGrams = servingSizeGrams
        self.proteinGrams = proteinGrams
        self.caloriesPerServing = caloriesPerServing
        self.carbsGrams = carbsGrams
        self.fatGrams = fatGrams
        self.fiberGrams = fiberGrams
        self.sugarGrams = sugarGrams
        self.sodiumMg = sodiumMg
        self.isNauseaSafe = isNauseaSafe
        self.giRisk = giRisk
        self.scannedAt = Date()
        self.source = source
    }

    var proteinDensity: Double {
        guard caloriesPerServing > 0 else { return 0 }
        return (proteinGrams * 4) / caloriesPerServing
    }
}

enum GIRiskLevel: String, Codable {
    case low = "Low"
    case moderate = "Moderate"
    case high = "High"
}

enum FoodSource: String, Codable {
    case barcodeScan = "Barcode Scan"
    case photoAnalysis = "Photo Analysis"
    case search = "Search"
    case manual = "Manual"
}
