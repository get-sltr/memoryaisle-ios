import SwiftUI

struct DashboardHero: View {
    let dayNumber: Int
    let medication: String
    let dose: String
    let focus: String
    let startWeight: Int
    let goalWeight: Int
    let timelineMonths: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(numberLine)
                .font(Theme.Editorial.Typography.capsBold(9))
                .tracking(2.9)
                .foregroundStyle(Theme.Editorial.onSurface)

            VStack(alignment: .leading, spacing: 0) {
                Text("Day \(dayNumber.asWord).")
                    .font(Theme.Editorial.Typography.displayHeroItalic())
                Text("Listen")
                    .font(Theme.Editorial.Typography.displayHeroItalic())
                Text("to the body.")
                    .font(Theme.Editorial.Typography.displayHero())
            }
            .foregroundStyle(Theme.Editorial.onSurface)
            .lineSpacing(-2)

            VStack(alignment: .leading, spacing: 2) {
                if !medication.isEmpty {
                    Text("CYCLE · \(medication.uppercased()) \(dose.uppercased())")
                }
                Text("FOCUS · \(focus.uppercased())")
                if startWeight > 0, goalWeight > 0 {
                    Text("\(startWeight) → \(goalWeight) LB · ~\(timelineMonths) MO")
                }
            }
            .font(Theme.Editorial.Typography.caps(8, weight: .semibold))
            .tracking(2)
            .foregroundStyle(Theme.Editorial.onSurfaceMuted)
            .lineSpacing(4)
        }
        .padding(.bottom, 22)
    }

    private var numberLine: String {
        let padded = String(format: "%02d", dayNumber)
        return "N° \(padded)"
    }
}

private extension Int {
    /// Spells out small numbers ("four"). Falls back to digits beyond ten so
    /// the hero reads "Day four." for early-cycle days and "Day 23." later.
    var asWord: String {
        switch self {
        case 1:  return "one"
        case 2:  return "two"
        case 3:  return "three"
        case 4:  return "four"
        case 5:  return "five"
        case 6:  return "six"
        case 7:  return "seven"
        case 8:  return "eight"
        case 9:  return "nine"
        case 10: return "ten"
        default: return String(self)
        }
    }
}
