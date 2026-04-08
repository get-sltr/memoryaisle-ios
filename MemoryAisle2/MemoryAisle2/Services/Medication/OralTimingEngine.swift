import Foundation

struct OralTimingEngine {

    struct FastingWindow {
        let pillTime: Date
        let earliestEatTime: Date
        let minutesRemaining: Int
        let isInFastingWindow: Bool
        let breakfastRecommendation: String
    }

    static func currentWindow(
        pillTime: Date,
        fastingMinutes: Int = 30
    ) -> FastingWindow {
        let calendar = Calendar.current
        let now = Date.now

        let pillToday = calendar.date(
            bySettingHour: calendar.component(.hour, from: pillTime),
            minute: calendar.component(.minute, from: pillTime),
            second: 0,
            of: now
        ) ?? pillTime

        let earliestEat = pillToday.addingTimeInterval(
            Double(fastingMinutes) * 60
        )

        let remaining: Int
        let inWindow: Bool

        if now < earliestEat && now >= pillToday {
            remaining = Int(earliestEat.timeIntervalSince(now) / 60)
            inWindow = true
        } else {
            remaining = 0
            inWindow = false
        }

        let recommendation = buildBreakfastRec(
            minutesRemaining: remaining,
            inWindow: inWindow
        )

        return FastingWindow(
            pillTime: pillToday,
            earliestEatTime: earliestEat,
            minutesRemaining: remaining,
            isInFastingWindow: inWindow,
            breakfastRecommendation: recommendation
        )
    }

    static func optimalPillTime(
        wakeTime: Date,
        preferredBreakfastTime: Date
    ) -> Date {
        let interval = preferredBreakfastTime.timeIntervalSince(wakeTime)
        let minutesBetween = Int(interval / 60)

        if minutesBetween >= 30 {
            return wakeTime
        }

        return preferredBreakfastTime.addingTimeInterval(-30 * 60)
    }

    private static func buildBreakfastRec(
        minutesRemaining: Int,
        inWindow: Bool
    ) -> String {
        if !inWindow {
            return "Fasting window complete. High-protein breakfast recommended."
        }

        if minutesRemaining > 20 {
            return "Pill just taken. Wait \(minutesRemaining) min before eating. Hydrate with plain water."
        }

        if minutesRemaining > 10 {
            return "\(minutesRemaining) min left. Start prepping a protein-first breakfast now."
        }

        return "Almost there. \(minutesRemaining) min until you can eat."
    }
}
