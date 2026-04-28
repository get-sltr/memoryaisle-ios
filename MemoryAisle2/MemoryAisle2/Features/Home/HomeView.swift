import SwiftData
import SwiftUI

/// Editorial Today screen. Single-column layout under the masthead:
/// hero → cycle/appetite/focus caps → ledger → Mira line. No scroll
/// (matches the reference); content sized to the device's safe area.
struct HomeView: View {
    let mode: MAMode
    let onTapWordmark: () -> Void

    @Query private var profiles: [UserProfile]
    @Query(sort: \BodyComposition.date, order: .reverse) private var bodyCompRecords: [BodyComposition]
    @Query(sort: \NutritionLog.date, order: .reverse) private var nutritionLogs: [NutritionLog]
    @Query(sort: \MedicationProfile.startDate, order: .reverse) private var medications: [MedicationProfile]

    private var profile: UserProfile? { profiles.first }
    private var medication: MedicationProfile? { medications.first }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Masthead(
                wordmark: "MEMORY AISLE",
                trailing: mastheadTrailing,
                onTapWordmark: onTapWordmark
            )
            .padding(.bottom, 30)

            Text(sectionLabel)
                .font(Theme.Editorial.Typography.capsBold(10))
                .tracking(3.5)
                .textCase(.uppercase)
                .foregroundStyle(Theme.Editorial.onSurface)
                .padding(.bottom, 18)

            HeroDisplay(
                lineOne: heroLineOne,
                lineTwoItalic: heroLineTwoItalic,
                lineThree: heroLineThree
            )
            .padding(.bottom, 18)

            VStack(alignment: .leading, spacing: 0) {
                Text(cycleLine)
                Text(appetiteLine)
                Text(focusLine)
            }
            .font(Theme.Editorial.Typography.caps(9, weight: .semibold))
            .tracking(2)
            .textCase(.uppercase)
            .foregroundStyle(Theme.Editorial.onSurfaceMuted)
            .lineSpacing(4)

            Spacer(minLength: 0)

            VStack(spacing: 0) {
                HairlineDivider()
                    .padding(.bottom, 14)

                Text("TODAY, IN MEASURE")
                    .font(Theme.Editorial.Typography.capsBold(10))
                    .tracking(2.2)
                    .foregroundStyle(Theme.Editorial.onSurface)
                    .opacity(0.85)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 12)

                LedgerRow(name: "Protein",         value: proteinLedger)
                LedgerRow(name: "Hydration",       value: hydrationLedger)
                LedgerRow(name: "Lean mass · 30d", value: leanMassLedger)

                MiraLine(message: miraMessage)
                    .padding(.top, 14)
            }
            .padding(.bottom, 80)
        }
        .padding(.horizontal, Theme.Editorial.Spacing.pad)
        .padding(.top, Theme.Editorial.Spacing.topInset)
    }

    // MARK: - Masthead trailing

    private var mastheadTrailing: String {
        switch mode {
        case .day:   RomanNumeral.dateString(from: Date())
        case .night: RomanNumeral.eveningString(from: Date())
        }
    }

    // MARK: - Section label

    private var sectionLabel: String {
        let day = cycleDayNumber
        let nMark = "N° \(RomanNumeral.string(from: day))"
        return mode == .night ? "\(nMark) · EVENING" : nMark
    }

    private var cycleDayNumber: Int {
        let start = medication?.startDate ?? profile?.createdAt
        guard let start else { return 1 }
        let days = Calendar.current.dateComponents([.day], from: start, to: .now).day ?? 0
        return max(1, days + 1)
    }

    // MARK: - Hero copy

    private var heroLineOne: String {
        "Day \(EnglishNumber.word(from: cycleDayNumber))."
    }

    private var heroLineTwoItalic: String {
        mode == .night ? "Rest now," : "Be gentle"
    }

    private var heroLineThree: String {
        mode == .night ? "tomorrow waits." : "with the body."
    }

    // MARK: - Caps lines

    private var cycleLine: String {
        guard let med = medication else { return "CYCLE · NOT SET" }
        let drug = med.medication.rawValue.uppercased()
        let dose = med.doseAmount.uppercased()
        return "CYCLE · \(drug) \(dose)"
    }

    private var appetiteLine: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let timeOfDay: String
        switch hour {
        case 5..<12:  timeOfDay = "MORNING"
        case 12..<17: timeOfDay = "AFTERNOON"
        case 17..<21: timeOfDay = "EVENING"
        default:      timeOfDay = "LATE NIGHT"
        }
        return "\(timeOfDay) · \(appetiteText)"
    }

    private var appetiteText: String {
        // Without coupling to the full medication appetite predictor, infer
        // a light-touch label: post-injection appetite suppression peaks
        // 24-48h in, easing through the rest of the cycle.
        guard let med = medication, med.modality == .injectable, let injectionDay = med.injectionDay else {
            return "STEADY APPETITE"
        }
        let weekday = Calendar.current.component(.weekday, from: Date())
        let daysSinceShot = (weekday - injectionDay + 7) % 7
        switch daysSinceShot {
        case 0, 1: return "MILD APPETITE"
        case 2, 3: return "APPETITE EASING"
        default:   return "APPETITE STEADY"
        }
    }

    private var focusLine: String {
        let mode = profile?.productMode ?? .everyday
        switch mode {
        case .everyday:             return "FOCUS · PROTEIN"
        case .sensitiveStomach:     return "FOCUS · GENTLE"
        case .musclePreservation:   return "FOCUS · LEAN MASS"
        case .trainingPerformance:  return "FOCUS · PERFORMANCE"
        case .maintenanceTaper:     return "FOCUS · MAINTAIN"
        }
    }

    // MARK: - Ledger values

    private var todaysLogs: [NutritionLog] {
        nutritionLogs.filter { Calendar.current.isDateInToday($0.date) }
    }

    private var proteinConsumed: Double {
        todaysLogs.reduce(0) { $0 + $1.proteinGrams }
    }

    private var proteinLedger: String {
        let consumed = Int(proteinConsumed.rounded())
        let target = profile?.proteinTargetGrams ?? 0
        let consumedStr = String(format: "%03d", min(consumed, 999))
        return target > 0 ? "\(consumedStr) / \(target) g" : "\(consumedStr) g"
    }

    private var hydrationLedger: String {
        let liters = todaysLogs.reduce(0.0) { $0 + $1.waterLiters }
        return String(format: "%.1f L", liters)
    }

    private var leanMassLedger: String {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .now
        let recent = bodyCompRecords.filter { $0.date >= cutoff }
        guard let newest = recent.first, let oldest = recent.last, newest.id != oldest.id else {
            return "..."
        }
        let delta = newest.computedLeanMass - oldest.computedLeanMass
        let sign = delta >= 0 ? "+" : ""
        return String(format: "\(sign)%.1f lb", delta)
    }

    // MARK: - Mira line

    private var miraMessage: String {
        let consumed = proteinConsumed
        let target = Double(profile?.proteinTargetGrams ?? 0)
        let gap = target - consumed

        if mode == .night {
            if gap <= 0 { return "You closed the protein gap. Sleep well." }
            if gap < 20 { return "Almost there. Rest now, tomorrow waits." }
            return "Tomorrow, we close the gap, kindly."
        } else {
            if gap <= 0 { return "You're on track. Carry on, gently." }
            if gap < 30 { return "A protein-forward dinner closes the gap, kindly." }
            return "Aim for protein at lunch and dinner, kindly."
        }
    }
}
