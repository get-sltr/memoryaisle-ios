import Foundation

enum CyclePhase: String {
    case injectionDay = "Injection Day"
    case peakSuppression = "Peak Suppression"
    case steadyState = "Steady State"
    case appetiteReturn = "Appetite Return"
    case preInjection = "Pre-Injection"

    var dayRange: String {
        switch self {
        case .injectionDay: "Day 1"
        case .peakSuppression: "Days 2-3"
        case .steadyState: "Days 3-5"
        case .appetiteReturn: "Days 5-6"
        case .preInjection: "Day 7"
        }
    }

    var appetiteDescription: String {
        switch self {
        case .injectionDay: "Appetite dropping, possible nausea"
        case .peakSuppression: "Lowest appetite, highest nausea risk"
        case .steadyState: "Stable suppression, manageable appetite"
        case .appetiteReturn: "Appetite increasing, larger portions okay"
        case .preInjection: "Near-normal appetite, maximize protein"
        }
    }

    var proteinStrategy: String {
        switch self {
        case .injectionDay: "Protein shakes and soft foods"
        case .peakSuppression: "Small, frequent, protein-dense bites"
        case .steadyState: "Normal protein-first meals"
        case .appetiteReturn: "Increase portion sizes, add carbs"
        case .preInjection: "Full meals, hit protein target aggressively"
        }
    }

    var nauseaRisk: Double {
        switch self {
        case .injectionDay: 0.7
        case .peakSuppression: 0.9
        case .steadyState: 0.3
        case .appetiteReturn: 0.1
        case .preInjection: 0.05
        }
    }
}

struct InjectionCycleEngine {

    static func currentPhase(injectionDay: Int) -> CyclePhase {
        phase(forDate: .now, injectionDay: injectionDay)
    }

    /// Phase for an arbitrary date. Used by the weekly meal plan generator so
    /// each day in the 7-day window gets its accurate phase rather than today's.
    static func phase(forDate date: Date, injectionDay: Int, calendar: Calendar = .current) -> CyclePhase {
        let dayOffset = daysSince(injectionDay: injectionDay, on: date, calendar: calendar)
        switch dayOffset {
        case 0: return .injectionDay
        case 1...2: return .peakSuppression
        case 3...4: return .steadyState
        case 5: return .appetiteReturn
        default: return .preInjection
        }
    }

    static func daysSince(injectionDay: Int) -> Int {
        daysSince(injectionDay: injectionDay, on: .now)
    }

    static func daysSince(injectionDay: Int, on date: Date, calendar: Calendar = .current) -> Int {
        let weekday = calendar.component(.weekday, from: date)
        return (weekday - injectionDay + 7) % 7
    }

    static func daysUntilNext(injectionDay: Int) -> Int {
        let daysSince = daysSince(injectionDay: injectionDay)
        return daysSince == 0 ? 0 : 7 - daysSince
    }

    static func progressInCycle(injectionDay: Int) -> Double {
        Double(daysSince(injectionDay: injectionDay)) / 7.0
    }
}
