import Combine
import Foundation
import SwiftData

@MainActor
final class MedicationManager: ObservableObject {
    private let modelContext: ModelContext

    @Published var activeProfile: MedicationProfile?
    @Published var currentPhase: CyclePhase?
    @Published var appetiteLevel: Double = 0.5
    @Published var nauseaRisk: Double = 0.0

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func loadActiveProfile() {
        let descriptor = FetchDescriptor<MedicationProfile>(
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        activeProfile = try? modelContext.fetch(descriptor).first
        updateCycleState()
    }

    func createProfile(
        medication: Medication,
        modality: MedicationModality,
        dose: String,
        injectionDay: Int? = nil,
        pillTime: Date? = nil
    ) -> MedicationProfile {
        let profile = MedicationProfile(
            medication: medication,
            modality: modality,
            doseAmount: dose,
            injectionDay: injectionDay,
            pillTime: pillTime
        )
        modelContext.insert(profile)
        activeProfile = profile
        updateCycleState()
        return profile
    }

    func updateCycleState() {
        guard let profile = activeProfile else {
            currentPhase = nil
            appetiteLevel = 0.5
            nauseaRisk = 0.0
            return
        }

        switch profile.modality {
        case .injectable:
            updateInjectableCycle(profile)
        case .oralWithFasting:
            updateOralFastingCycle(profile)
        case .oralNoFasting:
            updateOralNoFastingCycle(profile)
        }
    }
}

// MARK: - Cycle Phase Calculations

extension MedicationManager {
    private func updateInjectableCycle(_ profile: MedicationProfile) {
        guard let day = profile.injectionDay else { return }
        let phase = InjectionCycleEngine.currentPhase(injectionDay: day)
        currentPhase = phase
        nauseaRisk = phase.nauseaRisk
        appetiteLevel = 1.0 - phase.nauseaRisk
    }

    private func updateOralFastingCycle(_ profile: MedicationProfile) {
        let weeksOn = profile.weeksOnMedication
        let titrationNausea: Double = switch weeksOn {
        case 1...2: 0.7
        case 3...4: 0.5
        case 5...8: 0.3
        default: 0.15
        }

        let hoursSincePill = hoursSincePillTime(profile)
        let acuteNausea: Double = switch hoursSincePill {
        case 0...2: 0.6
        case 2...4: 0.3
        default: 0.1
        }

        nauseaRisk = min(1.0, max(titrationNausea, acuteNausea))
        appetiteLevel = 1.0 - (nauseaRisk * 0.7)
        currentPhase = .steadyState
    }

    private func updateOralNoFastingCycle(_ profile: MedicationProfile) {
        let weeksOn = profile.weeksOnMedication
        nauseaRisk = switch weeksOn {
        case 1...2: 0.4
        case 3...4: 0.25
        default: 0.1
        }
        appetiteLevel = 1.0 - (nauseaRisk * 0.5)
        currentPhase = .steadyState
    }

    private func hoursSincePillTime(_ profile: MedicationProfile) -> Int {
        guard let pillTime = profile.pillTime else { return 12 }
        let calendar = Calendar.current
        let pillComponents = calendar.dateComponents(
            [.hour, .minute], from: pillTime
        )
        let nowComponents = calendar.dateComponents(
            [.hour, .minute], from: .now
        )
        let pillMinutes = (pillComponents.hour ?? 0) * 60
            + (pillComponents.minute ?? 0)
        let nowMinutes = (nowComponents.hour ?? 0) * 60
            + (nowComponents.minute ?? 0)
        let diff = nowMinutes - pillMinutes
        return max(0, diff / 60)
    }
}
