import Combine
import Foundation
import SwiftData

@MainActor
final class BodyCompTrend: ObservableObject {
    private let modelContext: ModelContext

    @Published var entries: [BodyComposition] = []
    @Published var weightTrend: TrendDirection = .stable
    @Published var leanMassTrend: TrendDirection = .stable
    @Published var fatMassTrend: TrendDirection = .stable

    enum TrendDirection: String {
        case increasing = "Increasing"
        case decreasing = "Decreasing"
        case stable = "Stable"
    }

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func refresh() {
        let fourWeeksAgo = Calendar.current.date(
            byAdding: .day, value: -28, to: .now
        ) ?? .now

        let predicate = #Predicate<BodyComposition> {
            $0.date >= fourWeeksAgo
        }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\.date)]
        entries = (try? modelContext.fetch(descriptor)) ?? []

        analyzeTrends()
    }

    func addEntry(
        weightLbs: Double,
        bodyFatPercent: Double? = nil,
        waistInches: Double? = nil,
        source: BodyCompSource = .manual,
        photoData: Data? = nil
    ) {
        let leanMass: Double?
        if let bf = bodyFatPercent {
            leanMass = weightLbs * (1 - bf / 100)
        } else {
            leanMass = nil
        }

        let entry = BodyComposition(
            weightLbs: weightLbs,
            bodyFatPercent: bodyFatPercent,
            leanMassLbs: leanMass,
            waistInches: waistInches,
            source: source,
            photoData: photoData
        )
        modelContext.insert(entry)
        entries.append(entry)
        analyzeTrends()
    }

    var latestWeight: Double? { entries.last?.weightLbs }
    var latestLeanMass: Double? { entries.last?.computedLeanMass }
    var latestBodyFat: Double? { entries.last?.bodyFatPercent }

    var weightChange: Double? {
        guard entries.count >= 2 else { return nil }
        let first = entries.first?.weightLbs ?? 0
        let last = entries.last?.weightLbs ?? 0
        return last - first
    }

    var leanMassChange: Double? {
        guard entries.count >= 2 else { return nil }
        let first = entries.first?.computedLeanMass ?? 0
        let last = entries.last?.computedLeanMass ?? 0
        return last - first
    }

    var musclePreservationScore: Double {
        guard let wChange = weightChange,
              let lmChange = leanMassChange,
              wChange != 0 else { return 1.0 }

        if wChange >= 0 { return 1.0 }

        let fatLoss = wChange - lmChange
        let leanLossRatio = abs(lmChange) / abs(wChange)

        if leanLossRatio < 0.2 { return 1.0 }
        if leanLossRatio < 0.3 { return 0.8 }
        if leanLossRatio < 0.39 { return 0.6 }
        if fatLoss < 0 { return 0.4 }
        return 0.3
    }

    private func analyzeTrends() {
        guard entries.count >= 3 else {
            weightTrend = .stable
            leanMassTrend = .stable
            fatMassTrend = .stable
            return
        }

        let recentCount = min(entries.count, 5)
        let recent = Array(entries.suffix(recentCount))

        weightTrend = computeTrend(recent.map(\.weightLbs))
        leanMassTrend = computeTrend(recent.map(\.computedLeanMass))
        fatMassTrend = computeTrend(recent.map(\.computedFatMass))
    }

    private func computeTrend(_ values: [Double]) -> TrendDirection {
        guard values.count >= 3 else { return .stable }

        let first = values.prefix(values.count / 2)
        let second = values.suffix(values.count / 2)

        let firstAvg = first.reduce(0, +) / Double(first.count)
        let secondAvg = second.reduce(0, +) / Double(second.count)
        let diff = secondAvg - firstAvg

        if abs(diff) < 0.5 { return .stable }
        return diff > 0 ? .increasing : .decreasing
    }
}
