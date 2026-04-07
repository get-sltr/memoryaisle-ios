import HealthKit
import SwiftUI

@Observable
final class HealthKitManager {
    private let store = HKHealthStore()

    var isAuthorized = false
    var latestWeight: Double?
    var weightUnit: String = "lbs"
    var weightHistory: [(date: Date, value: Double)] = []

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    // MARK: - Authorization

    func requestAuthorization() async {
        guard isAvailable else { return }

        let readTypes: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .bodyMass)!,
            HKObjectType.quantityType(forIdentifier: .leanBodyMass)!,
            HKObjectType.quantityType(forIdentifier: .bodyFatPercentage)!,
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.workoutType()
        ]

        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            isAuthorized = true
            await fetchLatestWeight()
            await fetchWeightHistory()
        } catch {
            isAuthorized = false
        }
    }

    // MARK: - Weight

    func fetchLatestWeight() async {
        guard let type = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { return }

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { [weak self] _, samples, _ in
            guard let sample = samples?.first as? HKQuantitySample else { return }

            let lbs = sample.quantity.doubleValue(for: .pound())

            DispatchQueue.main.async {
                self?.latestWeight = lbs
            }
        }

        store.execute(query)
    }

    func fetchWeightHistory() async {
        guard let type = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { return }

        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: .now)!
        let predicate = HKQuery.predicateForSamples(withStart: thirtyDaysAgo, end: .now, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { [weak self] _, samples, _ in
            guard let samples = samples as? [HKQuantitySample] else { return }

            let history = samples.map { sample in
                (date: sample.startDate, value: sample.quantity.doubleValue(for: .pound()))
            }

            DispatchQueue.main.async {
                self?.weightHistory = history
            }
        }

        store.execute(query)
    }
}
