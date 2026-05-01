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

    // MARK: - Care team + refill (added 2026-05-01)
    //
    // All optional so the SwiftData migration is lightweight — existing
    // rows decode with nil here and the Medication page treats nil as
    // "not yet set" rather than rendering empty values. Phone strings
    // are free-form (E.164 isn't enforced) so users can paste whatever
    // the prescriber's office gave them, including extensions.
    var providerName: String?
    var providerPhone: String?
    var pharmacyName: String?
    var pharmacyPhone: String?
    var refillDueDate: Date?
    var refillReminderEnabled: Bool?

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

enum DrugClass: String, Codable, Sendable {
    case semaglutide
    case tirzepatide
    case orforglipron
    case unknown

    /// Maps a `Medication` enum (which is brand-keyed) to its anonymized
    /// drug class. Used by Mira tools that work in class terms — the system
    /// prompt anonymizes brand names, so callers reach for the class.
    static func from(medication: Medication?) -> DrugClass {
        guard let medication else { return .unknown }
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
