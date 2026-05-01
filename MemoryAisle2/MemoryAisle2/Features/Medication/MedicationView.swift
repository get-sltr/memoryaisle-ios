import SwiftData
import SwiftUI

/// Editorial Medications screen. Two layouts based on `UserProfile.medicationModality`:
///   GLP-1 user (modality != nil) → regimen + cycle + appetite + allergies
///   Non-GLP-1 user (modality == nil) → allergies only
struct MedicationView: View {
    var mode: MAMode = .auto

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Query(sort: \MedicationProfile.startDate, order: .reverse) private var medications: [MedicationProfile]

    private var profile: UserProfile? { profiles.first }
    private var medication: MedicationProfile? { medications.first }

    var body: some View {
        ZStack {
            EditorialBackground(mode: mode)

            VStack(alignment: .leading, spacing: 0) {
                topBar
                content
            }
            .padding(.horizontal, Theme.Editorial.Spacing.pad)
            .padding(.top, 12)
        }
        .preferredColorScheme(.light)
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.Editorial.onSurface)
                    .frame(width: 32, height: 32)
                    .overlay(Circle().stroke(Theme.Editorial.hairline, lineWidth: 0.5))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
        .padding(.bottom, 16)
    }

    // MARK: - Content branching

    @ViewBuilder
    private var content: some View {
        if let profile {
            if profile.medicationModality != nil {
                glp1Layout(profile: profile)
            } else {
                allergiesOnlyLayout(profile: profile)
            }
        } else {
            allergiesOnlyLayout(profile: nil)
        }
    }

    // MARK: - GLP-1 layout

    private func glp1Layout(profile: UserProfile) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                Masthead(wordmark: "MEDICATIONS", trailing: modalityTrailing(profile))
                    .padding(.bottom, 28)

                regimenSection(profile)
                    .padding(.bottom, 28)

                cycleSection(profile)
                    .padding(.bottom, 28)

                appetiteSection(profile)
                    .padding(.bottom, 28)

                allergiesSection(binding: dietaryBinding(profile))
                    .padding(.bottom, 100)
            }
        }
    }

    // MARK: - Non-GLP-1 layout

    private func allergiesOnlyLayout(profile: UserProfile?) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                Masthead(
                    wordmark: "ALLERGIES",
                    trailing: profile.map(allergyCountTrailing) ?? "NONE SET"
                )
                .padding(.bottom, 28)

                if let profile {
                    allergiesSection(binding: dietaryBinding(profile))
                        .padding(.bottom, 100)
                } else {
                    Text("No profile found.")
                        .font(Theme.Editorial.Typography.body())
                        .foregroundStyle(Theme.Editorial.onSurfaceFaint)
                }
            }
        }
    }

    // MARK: - Sections

    private func regimenSection(_ profile: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("I · CURRENT REGIMEN")
            HairlineDivider().opacity(0.5)
            if let med = medication {
                regimenRow(label: "MEDICATION", value: med.medication.rawValue)
                regimenRow(label: "DOSE", value: med.doseAmount)
                regimenRow(label: "MODALITY", value: med.modality.displayName)
                if let day = med.injectionDay {
                    regimenRow(label: "INJECTION DAY", value: weekdayName(day))
                }
                if let pill = med.pillTime {
                    regimenRow(label: "PILL TIME", value: pillTimeString(pill))
                }
            } else {
                Text("Set up your medication in onboarding to see regimen details here.")
                    .font(Theme.Editorial.Typography.body())
                    .foregroundStyle(Theme.Editorial.onSurfaceFaint)
                    .padding(.top, 4)
            }
        }
    }

    private func cycleSection(_ profile: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("II · CYCLE PHASE")
            HairlineDivider().opacity(0.5)
            if let med = medication, med.modality == .injectable, let day = med.injectionDay {
                cycleBar(injectionDay: day, weekday: currentWeekday)
            } else if let med = medication {
                regimenRow(label: "WEEKS ON MED", value: "\(med.weeksOnMedication)")
                regimenRow(label: "PHASE", value: med.weeksOnMedication <= 4 ? "TITRATION" : "STEADY STATE")
            } else {
                Text("Cycle data appears once a regimen is recorded.")
                    .font(Theme.Editorial.Typography.body())
                    .foregroundStyle(Theme.Editorial.onSurfaceFaint)
            }
        }
    }

    private func appetiteSection(_ profile: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("III · APPETITE & SYMPTOMS")
            HairlineDivider().opacity(0.5)
            regimenRow(label: "APPETITE", value: appetiteText)
            regimenRow(label: "NAUSEA RISK", value: nauseaText)
            Text("Predictions update each day based on your dose phase and time since last dose.")
                .font(Theme.Editorial.Typography.body())
                .foregroundStyle(Theme.Editorial.onSurfaceFaint)
                .padding(.top, 6)
        }
    }

    private func allergiesSection(binding: Binding<[DietaryRestriction]>) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(medication == nil && profile?.medicationModality == nil ? "RESTRICTIONS" : "IV · ALLERGIES & RESTRICTIONS")
            HairlineDivider().opacity(0.5)
            AllergyChipGrid(selected: binding)
                .padding(.top, 4)
        }
    }

    // MARK: - Components

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(Theme.Editorial.Typography.capsBold(10))
            .tracking(3)
            .textCase(.uppercase)
            .foregroundStyle(Theme.Editorial.onSurface)
    }

    private func regimenRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(Theme.Editorial.Typography.caps(9, weight: .semibold))
                .tracking(2)
                .foregroundStyle(Theme.Editorial.onSurfaceMuted)
            Spacer()
            Text(value)
                .font(Theme.Editorial.Typography.body())
                .foregroundStyle(Theme.Editorial.onSurface)
        }
        .padding(.vertical, 6)
    }

    private func cycleBar(injectionDay: Int, weekday: Int) -> some View {
        let daysSinceShot = (weekday - injectionDay + 7) % 7
        let dayOfCycle = daysSinceShot + 1
        return VStack(alignment: .leading, spacing: 10) {
            regimenRow(label: "DAY OF CYCLE", value: "\(dayOfCycle) OF 7")
            HStack(spacing: 4) {
                ForEach(1...7, id: \.self) { day in
                    Capsule()
                        .fill(day <= dayOfCycle ? Theme.Editorial.onSurface : Theme.Editorial.onSurface.opacity(0.18))
                        .frame(height: 4)
                }
            }
        }
    }

    // MARK: - Computed copy

    private func modalityTrailing(_ profile: UserProfile) -> String {
        guard let modality = profile.medicationModality else { return "NOT SET" }
        switch modality {
        case .injectable:      return "INJECTABLE"
        case .oralWithFasting: return "ORAL · FASTING"
        case .oralNoFasting:   return "ORAL · NO FAST"
        }
    }

    private func allergyCountTrailing(_ profile: UserProfile) -> String {
        let count = profile.dietaryRestrictions.count
        return count == 0 ? "NONE SET" : "\(count) SELECTED"
    }

    private var currentWeekday: Int {
        Calendar.current.component(.weekday, from: .now)
    }

    private var appetiteText: String {
        guard let med = medication, med.modality == .injectable, let day = med.injectionDay else {
            return "STEADY"
        }
        let daysSinceShot = (currentWeekday - day + 7) % 7
        switch daysSinceShot {
        case 0, 1: return "MILD"
        case 2, 3: return "EASING"
        default:   return "STEADY"
        }
    }

    private var nauseaText: String {
        guard let med = medication else { return "LOW" }
        if med.weeksOnMedication <= 2 { return "ELEVATED" }
        if med.weeksOnMedication <= 4 { return "MODERATE" }
        return "LOW"
    }

    private func weekdayName(_ day: Int) -> String {
        let names = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
        let index = max(1, min(7, day)) - 1
        return names[index]
    }

    private func pillTimeString(_ time: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: time).uppercased()
    }

    // MARK: - Bindings

    private func dietaryBinding(_ profile: UserProfile) -> Binding<[DietaryRestriction]> {
        Binding(
            get: { profile.dietaryRestrictions },
            set: { profile.dietaryRestrictions = $0 }
        )
    }
}
