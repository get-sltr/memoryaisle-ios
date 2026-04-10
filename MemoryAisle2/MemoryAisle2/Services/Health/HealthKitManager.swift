import HealthKit
import SwiftUI

@Observable
final class HealthKitManager {
    private let store = HKHealthStore()

    var isAuthorized = false
    var latestWeight: Double?
    var latestBodyFatPercent: Double?
    var latestLeanBodyMassLbs: Double?
    var weightUnit: String = "lbs"
    var weightHistory: [(date: Date, value: Double)] = []

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    // MARK: - Authorization

    func requestAuthorization() async {
        guard isAvailable else { return }

        var readTypes: Set<HKObjectType> = []
        if let bodyMass = HKQuantityType.quantityType(forIdentifier: .bodyMass) {
            readTypes.insert(bodyMass)
        }
        if let leanBodyMass = HKQuantityType.quantityType(forIdentifier: .leanBodyMass) {
            readTypes.insert(leanBodyMass)
        }
        if let bodyFat = HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage) {
            readTypes.insert(bodyFat)
        }

        guard !readTypes.isEmpty else { return }

        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            isAuthorized = true
            await fetchLatestWeight()
            await fetchWeightHistory()
            await fetchLatestBodyFatPercentage()
            await fetchLatestLeanBodyMass()
        } catch {
            isAuthorized = false
        }
    }

    // MARK: - Weight

    func fetchLatestWeight() async {
        guard let type = HKQuantityType.quantityType(forIdentifier: .bodyMass) else {
            return
        }
        let sample = await fetchMostRecentSample(for: type)
        await MainActor.run {
            self.latestWeight = sample?.quantity.doubleValue(for: .pound())
        }
    }

    func fetchWeightHistory() async {
        guard let type = HKQuantityType.quantityType(forIdentifier: .bodyMass) else {
            return
        }
        guard let startDate = Calendar.current.date(
            byAdding: .day, value: -30, to: .now
        ) else { return }

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate, end: .now, options: .strictStartDate
        )
        let samples = await fetchSamples(for: type, predicate: predicate)
        let history = samples.map { sample in
            (date: sample.startDate, value: sample.quantity.doubleValue(for: .pound()))
        }
        await MainActor.run {
            self.weightHistory = history
        }
    }

    // MARK: - Body Fat Percentage

    func fetchLatestBodyFatPercentage() async {
        guard let type = HKQuantityType.quantityType(
            forIdentifier: .bodyFatPercentage
        ) else { return }

        let sample = await fetchMostRecentSample(for: type)
        await MainActor.run {
            if let value = sample?.quantity.doubleValue(for: .percent()) {
                self.latestBodyFatPercent = value * 100
            }
        }
    }

    // MARK: - Lean Body Mass

    func fetchLatestLeanBodyMass() async {
        guard let type = HKQuantityType.quantityType(
            forIdentifier: .leanBodyMass
        ) else { return }

        let sample = await fetchMostRecentSample(for: type)
        await MainActor.run {
            self.latestLeanBodyMassLbs = sample?.quantity.doubleValue(
                for: .pound()
            )
        }
    }

    // MARK: - Private Helpers

    private func fetchMostRecentSample(
        for type: HKQuantityType
    ) async -> HKQuantitySample? {
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: type)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)],
            limit: 1
        )
        let results = try? await descriptor.result(for: store)
        return results?.first
    }

    private func fetchSamples(
        for type: HKQuantityType,
        predicate: NSPredicate
    ) async -> [HKQuantitySample] {
        let samplePredicate = HKSamplePredicate.quantitySample(
            type: type,
            predicate: predicate
        )
        let descriptor = HKSampleQueryDescriptor(
            predicates: [samplePredicate],
            sortDescriptors: [SortDescriptor(\.startDate, order: .forward)]
        )
        return (try? await descriptor.result(for: store)) ?? []
    }
}
