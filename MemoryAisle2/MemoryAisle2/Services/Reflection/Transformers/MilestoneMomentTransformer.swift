import Foundation

/// Produces three flavors of milestone moments:
///
/// 1. Weight-toward-goal milestones — every 5 lbs crossed in the goal
///    direction. Works for both loss and gain goals.
/// 2. First-photo milestone — the earliest BodyComposition with photoData.
///    Anchors the Day 1 vs Today hero in Reflection.
/// 3. Goal-reached milestone — fires when the user's most recent weight
///    has reached or passed their goal weight.
struct MilestoneMomentTransformer: MomentTransformer {

    func moments(from records: ReflectionSourceRecords) throws -> [ReflectionMoment] {
        var result: [ReflectionMoment] = []

        let sortedRecords = records.bodyCompositions.sorted { $0.date < $1.date }

        // First-photo milestone
        if let firstPhoto = sortedRecords.first(where: { $0.photoData != nil }) {
            result.append(
                ReflectionMoment(
                    id: "milestoneFirstPhoto",
                    date: firstPhoto.date,
                    type: .milestone,
                    category: .milestone,
                    title: "Day 1",
                    description: "Where the journey starts.",
                    photoData: firstPhoto.photoData
                )
            )
        }

        // Weight-toward-goal milestones need a profile + goal
        guard let profile = records.userProfile,
              let goal = profile.goalWeightLbs,
              let startingWeight = sortedRecords.first?.weightLbs ?? profile.weightLbs
        else {
            return result
        }

        let isLossGoal = goal < startingWeight
        let isGainGoal = goal > startingWeight
        guard isLossGoal || isGainGoal else { return result }

        let direction = isLossGoal ? "down" : "up"
        let mostRecent = sortedRecords.last?.weightLbs ?? startingWeight
        let deltaToward: Double
        if isLossGoal {
            deltaToward = max(0, startingWeight - mostRecent)
        } else {
            deltaToward = max(0, mostRecent - startingWeight)
        }
        let maxMilestone = Int(deltaToward / 5) * 5

        if maxMilestone >= 5 {
            for lbs in stride(from: 5, through: maxMilestone, by: 5) {
                let targetWeight = isLossGoal
                    ? startingWeight - Double(lbs)
                    : startingWeight + Double(lbs)
                let crossingRecord: BodyComposition? = sortedRecords.first { rec in
                    isLossGoal
                        ? rec.weightLbs <= targetWeight
                        : rec.weightLbs >= targetWeight
                }
                guard let crossing = crossingRecord else { continue }

                result.append(
                    ReflectionMoment(
                        id: "milestoneWeight-\(lbs)",
                        date: crossing.date,
                        type: .milestone,
                        category: .milestone,
                        title: "\(lbs) pounds \(direction)",
                        description: milestoneDescription(
                            lbs: lbs,
                            goal: Int(goal),
                            startingWeight: startingWeight
                        ),
                        photoData: crossing.photoData
                    )
                )
            }
        }

        // Goal reached
        let goalReached = isLossGoal ? mostRecent <= goal : mostRecent >= goal
        if goalReached, let reachRecord = sortedRecords.first(where: { rec in
            isLossGoal ? rec.weightLbs <= goal : rec.weightLbs >= goal
        }) {
            result.append(
                ReflectionMoment(
                    id: "milestoneGoalReached",
                    date: reachRecord.date,
                    type: .milestone,
                    category: .milestone,
                    title: "You hit your goal.",
                    description: "You hit your goal.",
                    photoData: reachRecord.photoData
                )
            )
        }

        return result
    }

    private func milestoneDescription(
        lbs: Int,
        goal: Int,
        startingWeight: Double
    ) -> String {
        if lbs == 5 {
            return "First milestone on the way to \(goal) lbs."
        } else if lbs == 10 {
            return "Double digits. That is a real one."
        }
        let totalDelta = abs(Int(startingWeight) - goal)
        if totalDelta > 0 && Double(lbs) >= Double(totalDelta) * 0.5 && Double(lbs) < Double(totalDelta) {
            return "Halfway there."
        }
        return "\(lbs) pounds closer."
    }
}
