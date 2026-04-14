import Foundation

/// Transforms manual BodyComposition records into check-in moments.
///
/// Skips HealthKit-sourced records — those are passive and aren't user
/// gestures, so they don't deserve their own moment cards (they still feed
/// stats and the hero photo selection elsewhere).
///
/// The description for each moment is contextualized based on the user's
/// goal direction and how the weight changed since the previous check-in.
/// All copy follows the Mira voice rules: never judgy, always validating.
struct CheckInMomentTransformer: MomentTransformer {

    func moments(from records: ReflectionSourceRecords) throws -> [ReflectionMoment] {
        let manualRecords = records.bodyCompositions
            .filter { $0.source == .manual }
            .sorted { $0.date < $1.date }  // chronological order for week numbering

        guard !manualRecords.isEmpty else { return [] }

        let journeyStart = manualRecords.first?.date ?? .now
        let goal = records.userProfile?.goalWeightLbs
        let starting = records.userProfile?.weightLbs ?? manualRecords.first?.weightLbs

        var result: [ReflectionMoment] = []

        for (index, record) in manualRecords.enumerated() {
            let previous = index > 0 ? manualRecords[index - 1] : nil
            let isFirst = index == 0
            let weekNumber = weekNumber(from: journeyStart, to: record.date)
            let title = isFirst ? "First check-in" : "Week \(weekNumber) check-in"

            let description = buildDescription(
                current: record,
                previous: previous,
                startingWeight: starting,
                goalWeight: goal,
                isFirst: isFirst
            )

            result.append(
                ReflectionMoment(
                    id: "checkin-\(record.id)",
                    date: record.date,
                    type: .checkIn,
                    category: .standard,
                    title: title,
                    description: description,
                    photoData: record.photoData
                )
            )
        }
        return result
    }

    private func weekNumber(from start: Date, to date: Date) -> Int {
        let components = Calendar.current.dateComponents([.day], from: start, to: date)
        let days = components.day ?? 0
        return (days / 7) + 1
    }

    private func buildDescription(
        current: BodyComposition,
        previous: BodyComposition?,
        startingWeight: Double?,
        goalWeight: Double?,
        isFirst: Bool
    ) -> String {
        if isFirst {
            return "Your very first check-in. This is where the story starts."
        }
        guard let previous else {
            return "\(formatWeight(current.weightLbs)) lbs."
        }

        let currentW = current.weightLbs
        let previousW = previous.weightLbs
        let delta = currentW - previousW

        if abs(delta) < 0.1 {
            return "You showed up. That's the hard part."
        }

        guard let goal = goalWeight, let start = startingWeight else {
            return "\(formatWeight(currentW)) lbs."
        }

        let towardGoal: Bool
        if goal < start {
            towardGoal = delta < 0  // losing is toward goal
        } else if goal > start {
            towardGoal = delta > 0  // gaining is toward goal
        } else {
            towardGoal = abs(delta) < abs(previousW - start)
        }

        if towardGoal {
            let absDelta = abs(delta)
            return "\(formatWeight(currentW)) lbs. That's \(formatWeight(absDelta)) closer to your goal."
        } else {
            return "\(formatWeight(currentW)) lbs. The scale is just one signal. Look at you."
        }
    }

    private func formatWeight(_ lbs: Double) -> String {
        String(format: "%.1f", lbs)
    }
}
