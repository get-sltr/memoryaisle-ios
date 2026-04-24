import Foundation

/// Computes the (lbsDelta, direction, leanDelta, days) tuple for the
/// Reflection hero stats row. All math runs over typed source arrays —
/// no SwiftData fetches, no IO. Caller (the view) feeds in the records
/// from its @Query properties.
struct TransformationStats: Equatable {
    let lbsDelta: Double?
    let direction: Direction
    let leanDelta: Double?
    let days: Int?

    enum Direction: Equatable {
        case lost
        case gained
        case none
    }
}

@MainActor
struct TransformationStatsService {

    func stats(from records: ReflectionSourceRecords) -> TransformationStats {
        let sorted = records.bodyCompositions.sorted { $0.date < $1.date }
        let profile = records.userProfile

        let starting: Double? = sorted.first?.weightLbs ?? profile?.weightLbs
        let current: Double? = sorted.last?.weightLbs ?? starting
        let goal = profile?.goalWeightLbs

        let (lbsDelta, direction) = computeLbsDelta(
            starting: starting,
            current: current,
            goal: goal
        )
        let leanDelta = computeLeanDelta(records: sorted)
        let days = computeDays(records: sorted)

        return TransformationStats(
            lbsDelta: lbsDelta,
            direction: direction,
            leanDelta: leanDelta,
            days: days
        )
    }

    private func computeLbsDelta(
        starting: Double?,
        current: Double?,
        goal: Double?
    ) -> (Double?, TransformationStats.Direction) {
        guard let start = starting, let now = current, let g = goal else {
            return (nil, .none)
        }
        if g < start {
            return (max(0, start - now), .lost)
        } else if g > start {
            return (max(0, now - start), .gained)
        } else {
            return (abs(now - start), .none)
        }
    }

    private func computeLeanDelta(records: [BodyComposition]) -> Double? {
        guard records.count >= 2 else { return nil }
        let first = records.first!
        let last = records.last!
        let hasFirstLean = first.leanMassLbs != nil || first.bodyFatPercent != nil
        let hasLastLean = last.leanMassLbs != nil || last.bodyFatPercent != nil
        guard hasFirstLean && hasLastLean else { return nil }
        return last.computedLeanMass - first.computedLeanMass
    }

    private func computeDays(records: [BodyComposition]) -> Int? {
        if let stored = UserScopedDefaults.object(forKey: "journeyStartDate") as? Date {
            return daysBetween(stored, .now)
        }
        if let earliest = records.first?.date {
            return daysBetween(earliest, .now)
        }
        return nil
    }

    private func daysBetween(_ start: Date, _ end: Date) -> Int {
        Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0
    }
}
