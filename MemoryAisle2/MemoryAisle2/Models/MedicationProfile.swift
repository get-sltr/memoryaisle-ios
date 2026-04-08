import Foundation
import SwiftData

@Model
final class MedicationProfile {
    var id: String
    var medication: Medication
    var modality: MedicationModality
    var doseAmount: String
    var startDate: Date
    var injectionDay: Int?
    var pillTime: Date?
    var fastingWindowMinutes: Int
    var currentPhaseWeek: Int
    var isOnTaper: Bool
    var taperStartDate: Date?
    var previousDose: String?
    var notes: String?

    init(
        medication: Medication,
        modality: MedicationModality,
        doseAmount: String,
        startDate: Date = .now,
        injectionDay: Int? = nil,
        pillTime: Date? = nil,
        currentPhaseWeek: Int = 1
    ) {
        self.id = UUID().uuidString
        self.medication = medication
        self.modality = modality
        self.doseAmount = doseAmount
        self.startDate = startDate
        self.injectionDay = injectionDay
        self.pillTime = pillTime
        self.currentPhaseWeek = currentPhaseWeek
        self.isOnTaper = false

        switch modality {
        case .oralWithFasting:
            self.fastingWindowMinutes = 30
        case .oralNoFasting, .injectable:
            self.fastingWindowMinutes = 0
        }
    }

    var weeksOnMedication: Int {
        let days = Calendar.current.dateComponents(
            [.day], from: startDate, to: .now
        ).day ?? 0
        return max(1, days / 7)
    }

    var drugClass: DrugClass {
        switch medication {
        case .ozempic, .wegovy, .wegovyPill, .rybelsus,
             .compoundedSemaglutide:
            return .semaglutide
        case .mounjaro, .zepbound, .compoundedTirzepatide:
            return .tirzepatide
        case .foundayo:
            return .orforglipron
        case .other:
            return .unknown
        }
    }
}

enum DrugClass: String, Codable {
    case semaglutide
    case tirzepatide
    case orforglipron
    case unknown
}
