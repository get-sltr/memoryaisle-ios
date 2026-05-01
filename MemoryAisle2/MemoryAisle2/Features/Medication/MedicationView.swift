import SwiftData
import SwiftUI

/// Editorial Medications page — the dedicated home for prescription
/// operational data (dose, provider, pharmacy, refill). Distinct from
/// the Journey page's IV · MEDICATION block, which stays as a summary
/// (cycle phase, weeks, next dose). This page is where the user comes
/// when something operational changes.
///
/// Reads from `MedicationProfile` (extended 2026-05-01 with
/// provider/pharmacy/refill fields, all optional) and falls back to
/// `UserProfile.medication` for users who haven't promoted the data
/// into a MedicationProfile row yet.
///
/// Routed from the menu's "Medications" row in `III · HEALTH`.
struct MedicationView: View {
    var mode: MAMode = .auto

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MedicationProfile.startDate, order: .reverse) private var medications: [MedicationProfile]
    @Query private var profiles: [UserProfile]

    @State private var editingField: EditingField?

    private var med: MedicationProfile? { medications.first }
    private var profile: UserProfile? { profiles.first }

    /// Non-GLP-1 users (no medication of any flavor recorded) see a slimmer
    /// "Allergies & Restrictions" version of this surface — same canvas,
    /// just the dietary chip grid. The medication-specific sections,
    /// safety note, and footer are hidden for them.
    private var isOnGLP: Bool {
        profile?.medicationModality != nil
            || med != nil
            || profile?.medication != nil
    }

    private enum EditingField: Identifiable {
        case providerName, providerPhone
        case pharmacyName, pharmacyPhone
        case refillDate
        case dose

        var id: String { String(describing: self) }
    }

    var body: some View {
        ZStack {
            EditorialBackground(mode: mode)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    HairlineDivider().padding(.vertical, 8)

                    if isOnGLP {
                        currentScriptSection
                        sectionDivider
                        providerSection
                        sectionDivider
                        pharmacySection
                        sectionDivider
                        refillSection
                        sectionDivider
                        cycleSection
                        sectionDivider
                        allergiesSection
                        HairlineDivider().padding(.vertical, 8)
                        miraGuardrailsNote
                        footer
                    } else {
                        allergiesSection
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 60)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)

            VStack {
                HStack {
                    Spacer()
                    doneButton
                }
                .padding(.top, 16)
                .padding(.trailing, 24)
                Spacer()
            }
        }
        .preferredColorScheme(.light)
        .ignoresSafeArea()
        .sheet(item: $editingField) { field in
            editorSheet(for: field)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 56)
            Image(systemName: isOnGLP ? "cross.case" : "leaf")
                .font(.system(size: 22))
                .foregroundStyle(Theme.Editorial.onSurface)
                .padding(.bottom, 14)
            Text(isOnGLP ? "Medications" : "Allergies & Restrictions")
                .font(.system(size: 26, weight: .regular, design: .serif))
                .tracking(0.6)
                .foregroundStyle(Theme.Editorial.onSurface)
            Text(isOnGLP
                 ? "DOSE · PROVIDER · PHARMACY · REFILL"
                 : "DIETARY SAFETY · WHAT TO AVOID")
                .font(Theme.Editorial.Typography.caps(9, weight: .medium))
                .tracking(2.8)
                .foregroundStyle(Theme.Editorial.onSurfaceMuted)
                .padding(.top, 8)
                .padding(.bottom, 28)
        }
        .frame(maxWidth: .infinity)
    }

    private var doneButton: some View {
        Button {
            HapticManager.light()
            dismiss()
        } label: {
            Text("DONE")
                .font(Theme.Editorial.Typography.capsBold(11))
                .tracking(2.0)
                .foregroundStyle(Theme.Editorial.onSurface.opacity(0.85))
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Sections

    private var currentScriptSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("I · CURRENT SCRIPT")

            VStack(alignment: .leading, spacing: 4) {
                Text(scriptTitle)
                    .font(.system(size: 22, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(Theme.Editorial.onSurface)
                Text(scriptMeta)
                    .font(Theme.Editorial.Typography.caps(10, weight: .medium))
                    .tracking(2.4)
                    .foregroundStyle(Theme.Editorial.onSurface.opacity(0.55))
            }
            .padding(.vertical, 4)
            .padding(.bottom, 12)

            ledgerEditableRow(
                label: "Dose",
                value: med?.doseAmount ?? profile?.doseAmount ?? "—",
                editing: .dose
            )
            ledgerRow(
                label: "Cadence",
                value: cadenceLabel
            )
            ledgerRow(
                label: "Started",
                value: startedLabel
            )
        }
    }

    private var providerSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("II · PROVIDER")
            ledgerEditableRow(
                label: "Name",
                value: med?.providerName ?? "—",
                editing: .providerName
            )
            ledgerEditableRow(
                label: "Phone",
                value: med?.providerPhone ?? "—",
                editing: .providerPhone,
                callable: med?.providerPhone
            )
        }
    }

    private var pharmacySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("III · PHARMACY")
            ledgerEditableRow(
                label: "Name",
                value: med?.pharmacyName ?? "—",
                editing: .pharmacyName
            )
            ledgerEditableRow(
                label: "Phone",
                value: med?.pharmacyPhone ?? "—",
                editing: .pharmacyPhone,
                callable: med?.pharmacyPhone
            )
        }
    }

    private var refillSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("IV · REFILL")
            ledgerEditableRow(
                label: "Due",
                value: refillDateLabel,
                editing: .refillDate
            )

            HStack {
                Text("Reminder")
                    .font(Theme.Editorial.Typography.body())
                    .foregroundStyle(Theme.Editorial.onSurface.opacity(0.7))
                Spacer()
                Toggle("", isOn: refillReminderBinding)
                    .labelsHidden()
                    .tint(Color(red: 0.961, green: 0.851, blue: 0.478))
            }
            .padding(.vertical, 8)
            .overlay(alignment: .top) {
                Rectangle().fill(Theme.Editorial.onSurface.opacity(0.08)).frame(height: 0.5)
            }

            if let due = med?.refillDueDate, due > .now {
                let days = Calendar.current.dateComponents([.day], from: .now, to: due).day ?? 0
                Text("\(days) DAY\(days == 1 ? "" : "S") UNTIL REFILL")
                    .font(Theme.Editorial.Typography.caps(9, weight: .medium))
                    .tracking(2.4)
                    .foregroundStyle(Theme.Editorial.onSurface.opacity(0.45))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 10)
            }
        }
    }

    private var cycleSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("V · CYCLE")
            if let phase = cyclePhaseLine {
                ledgerRow(label: "Phase", value: phase)
            }
            ledgerRow(label: "Weeks On", value: RomanNumeral.string(from: weeksOnMedication))
            if let next = nextDoseLine {
                ledgerRow(label: "Next Dose", value: next)
            }
        }
    }

    /// VI for GLP-1 users (after Cycle); the only section non-GLP-1 users
    /// see. Bound to `UserProfile.dietaryRestrictions` via SwiftData.
    private var allergiesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel(isOnGLP ? "VI · ALLERGIES & RESTRICTIONS" : "RESTRICTIONS")
            if let profile {
                AllergyChipGrid(selected: dietaryBinding(profile))
            } else {
                Text("Complete onboarding to set dietary restrictions.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.Editorial.onSurfaceFaint)
            }
        }
    }

    private func dietaryBinding(_ profile: UserProfile) -> Binding<[DietaryRestriction]> {
        Binding(
            get: { profile.dietaryRestrictions },
            set: { profile.dietaryRestrictions = $0 }
        )
    }

    // MARK: - Mira guardrail note

    /// Visible reminder of the safety boundary on this surface. Not legal
    /// fine print — a one-line gold caps statement so users understand
    /// what Mira will and won't do when they ask her about meds. Pairs
    /// with the prompt-side hard lines (see `MiraEngine`).
    private var miraGuardrailsNote: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MIRA · MEDICATION SAFETY")
                .font(Theme.Editorial.Typography.caps(9, weight: .semibold))
                .tracking(2.8)
                .foregroundStyle(Color(red: 0.961, green: 0.851, blue: 0.478).opacity(0.9))
            Text("Mira knows your medication and your symptoms but never recommends dose changes, switching meds, or switching pharmacies. Those are conversations for your prescriber. She can help you draft what to bring to that visit.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.Editorial.onSurface.opacity(0.7))
                .lineSpacing(4)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.18))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color(red: 0.961, green: 0.851, blue: 0.478).opacity(0.5))
                .frame(width: 1)
        }
        .padding(.top, 16)
    }

    // MARK: - Empty state

    private var noMedicationState: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("No medication set yet.")
                .font(.system(size: 17, weight: .light, design: .serif))
                .italic()
                .foregroundStyle(Theme.Editorial.onSurface)
            Text("ADD ONE FROM ONBOARDING OR YOUR JOURNEY PAGE TO SEE PROVIDER, PHARMACY, AND REFILL DETAILS HERE.")
                .font(Theme.Editorial.Typography.caps(9, weight: .medium))
                .tracking(2.2)
                .foregroundStyle(Theme.Editorial.onSurface.opacity(0.5))
                .lineSpacing(2)
        }
        .padding(.vertical, 30)
    }

    // MARK: - Editor sheet

    @ViewBuilder
    private func editorSheet(for field: EditingField) -> some View {
        switch field {
        case .providerName:
            TextEditorSheet(title: "PROVIDER NAME",
                            initial: med?.providerName ?? "",
                            placeholder: "Dr. Last name") { value in
                med?.providerName = value.isEmpty ? nil : value
            }
        case .providerPhone:
            TextEditorSheet(title: "PROVIDER PHONE",
                            initial: med?.providerPhone ?? "",
                            placeholder: "555 123 4567",
                            keyboard: .phonePad) { value in
                med?.providerPhone = value.isEmpty ? nil : value
            }
        case .pharmacyName:
            TextEditorSheet(title: "PHARMACY NAME",
                            initial: med?.pharmacyName ?? "",
                            placeholder: "Pharmacy + location") { value in
                med?.pharmacyName = value.isEmpty ? nil : value
            }
        case .pharmacyPhone:
            TextEditorSheet(title: "PHARMACY PHONE",
                            initial: med?.pharmacyPhone ?? "",
                            placeholder: "555 123 4567",
                            keyboard: .phonePad) { value in
                med?.pharmacyPhone = value.isEmpty ? nil : value
            }
        case .refillDate:
            DatePickerSheet(
                title: "REFILL DUE",
                initial: med?.refillDueDate ?? .now
            ) { date in
                med?.refillDueDate = date
            }
        case .dose:
            TextEditorSheet(title: "DOSE",
                            initial: med?.doseAmount ?? profile?.doseAmount ?? "",
                            placeholder: "0.5 mg") { value in
                if let m = med {
                    m.doseAmount = value
                } else {
                    profile?.doseAmount = value
                }
            }
        }
    }

    // MARK: - Section + row primitives

    @ViewBuilder
    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(Theme.Editorial.Typography.caps(9, weight: .medium))
            .tracking(2.8)
            .foregroundStyle(Theme.Editorial.onSurfaceMuted)
            .padding(.vertical, 14)
            .padding(.horizontal, 4)
    }

    private var sectionDivider: some View {
        HairlineDivider().padding(.vertical, 8)
    }

    @ViewBuilder
    private func ledgerRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(Theme.Editorial.Typography.body())
                .foregroundStyle(Theme.Editorial.onSurface.opacity(0.7))
            Spacer()
            Text(value)
                .font(Theme.Editorial.Typography.caps(11, weight: .semibold))
                .tracking(1.6)
                .foregroundStyle(Theme.Editorial.onSurface)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.Editorial.onSurface.opacity(0.08)).frame(height: 0.5)
        }
    }

    @ViewBuilder
    private func ledgerEditableRow(
        label: String,
        value: String,
        editing field: EditingField,
        callable: String? = nil
    ) -> some View {
        HStack {
            Text(label)
                .font(Theme.Editorial.Typography.body())
                .foregroundStyle(Theme.Editorial.onSurface.opacity(0.7))
            Spacer()
            HStack(spacing: 12) {
                if let phone = callable, !phone.isEmpty, value != "—" {
                    Button {
                        HapticManager.light()
                        if let url = URL(string: "tel://\(phone.filter { "0123456789".contains($0) })") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Image(systemName: "phone")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color(red: 0.961, green: 0.851, blue: 0.478))
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(Theme.Editorial.onSurface.opacity(0.08)))
                            .overlay(Circle().stroke(Theme.Editorial.onSurface.opacity(0.2), lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Call \(label)")
                }

                Button {
                    HapticManager.light()
                    editingField = field
                } label: {
                    HStack(spacing: 6) {
                        Text(value)
                            .font(Theme.Editorial.Typography.caps(11, weight: .semibold))
                            .tracking(1.6)
                            .foregroundStyle(Theme.Editorial.onSurface)
                            .lineLimit(1)
                        Image(systemName: "pencil")
                            .font(.system(size: 9))
                            .foregroundStyle(Theme.Editorial.onSurface.opacity(0.5))
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.Editorial.onSurface.opacity(0.08)).frame(height: 0.5)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkle")
                .font(.system(size: 10))
                .foregroundStyle(Theme.Editorial.onSurface.opacity(0.5))
            Text("v 2.0.0")
                .font(Theme.Editorial.Typography.caps(9, weight: .regular))
                .tracking(2.8)
                .foregroundStyle(Theme.Editorial.onSurface.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 32)
        .padding(.bottom, 8)
    }

    // MARK: - Computed

    private var scriptTitle: String {
        if let medName = med?.medication.rawValue { return medName }
        if let medName = profile?.medication?.rawValue { return medName }
        return "—"
    }

    private var scriptMeta: String {
        var parts: [String] = []
        if let dose = med?.doseAmount ?? profile?.doseAmount, !dose.isEmpty {
            parts.append(dose.uppercased())
        }
        parts.append(cadenceLabel)
        return parts.joined(separator: " · ")
    }

    private var cadenceLabel: String {
        let modality = med?.modality ?? profile?.medicationModality
        switch modality {
        case .injectable: return "WEEKLY INJECTION"
        case .oralWithFasting: return "DAILY · FASTING"
        case .oralNoFasting: return "DAILY"
        case .none: return "—"
        }
    }

    private var startedLabel: String {
        guard let date = med?.startDate else { return "—" }
        let cal = Calendar.current
        return "\(RomanNumeral.string(from: cal.component(.month, from: date))) · \(RomanNumeral.string(from: cal.component(.day, from: date))) · \(RomanNumeral.string(from: cal.component(.year, from: date)))"
    }

    private var refillDateLabel: String {
        guard let date = med?.refillDueDate else { return "—" }
        let cal = Calendar.current
        return "\(RomanNumeral.string(from: cal.component(.month, from: date))) · \(RomanNumeral.string(from: cal.component(.day, from: date)))"
    }

    private var refillReminderBinding: Binding<Bool> {
        Binding(
            get: { med?.refillReminderEnabled ?? false },
            set: { med?.refillReminderEnabled = $0 }
        )
    }

    private var weeksOnMedication: Int {
        guard let m = med else { return 1 }
        return m.weeksOnMedication
    }

    private var cyclePhaseLine: String? {
        guard let day = med?.injectionDay ?? profile?.injectionDay else { return nil }
        let phase = InjectionCycleEngine.currentPhase(injectionDay: day)
        return phase.rawValue.uppercased()
    }

    private var nextDoseLine: String? {
        guard let day = med?.injectionDay ?? profile?.injectionDay else { return nil }
        let cal = Calendar.current
        let today = cal.component(.weekday, from: .now)
        let daysUntil = (day - today + 7) % 7
        let target = cal.date(byAdding: .day, value: daysUntil == 0 ? 7 : daysUntil, to: .now) ?? .now
        let f = DateFormatter()
        f.dateFormat = "EEE"
        let weekday = f.string(from: target).uppercased()
        return "\(weekday) · \(RomanNumeral.string(from: cal.component(.day, from: target)))"
    }
}

// MARK: - Editor sheets

/// Tiny modal for editing a single string field on the Medication page.
/// Editorial styling matches the parent page so the transition feels
/// continuous instead of dropping into a system-default form.
private struct TextEditorSheet: View {
    let title: String
    let initial: String
    let placeholder: String
    var keyboard: UIKeyboardType = .default
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            EditorialBackground(mode: .night)

            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Button { dismiss() } label: {
                        Text("CANCEL")
                            .font(Theme.Editorial.Typography.capsBold(11))
                            .tracking(2.0)
                            .foregroundStyle(Theme.Editorial.onSurface.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Button {
                        onSave(draft.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss()
                    } label: {
                        Text("SAVE")
                            .font(Theme.Editorial.Typography.capsBold(11))
                            .tracking(2.0)
                            .foregroundStyle(Color(red: 0.961, green: 0.851, blue: 0.478))
                    }
                    .buttonStyle(.plain)
                }

                Text(title)
                    .font(Theme.Editorial.Typography.caps(10, weight: .semibold))
                    .tracking(3.0)
                    .foregroundStyle(Theme.Editorial.onSurface.opacity(0.7))

                TextField(placeholder, text: $draft)
                    .focused($focused)
                    .keyboardType(keyboard)
                    .font(.system(size: 22, design: .serif))
                    .foregroundStyle(Theme.Editorial.onSurface)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Theme.Editorial.onSurface.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Theme.Editorial.onSurface.opacity(0.2), lineWidth: 0.5)
                    )

                Spacer()
            }
            .padding(28)
        }
        .preferredColorScheme(.light)
        .onAppear {
            draft = initial
            focused = true
        }
        .presentationDetents([.medium])
    }
}

private struct DatePickerSheet: View {
    let title: String
    let initial: Date
    let onSave: (Date) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var date: Date = .now

    var body: some View {
        ZStack {
            EditorialBackground(mode: .night)

            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Button { dismiss() } label: {
                        Text("CANCEL")
                            .font(Theme.Editorial.Typography.capsBold(11))
                            .tracking(2.0)
                            .foregroundStyle(Theme.Editorial.onSurface.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Button {
                        onSave(date)
                        dismiss()
                    } label: {
                        Text("SAVE")
                            .font(Theme.Editorial.Typography.capsBold(11))
                            .tracking(2.0)
                            .foregroundStyle(Color(red: 0.961, green: 0.851, blue: 0.478))
                    }
                    .buttonStyle(.plain)
                }

                Text(title)
                    .font(Theme.Editorial.Typography.caps(10, weight: .semibold))
                    .tracking(3.0)
                    .foregroundStyle(Theme.Editorial.onSurface.opacity(0.7))

                DatePicker("", selection: $date, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .colorScheme(.dark)
                    .tint(Color(red: 0.961, green: 0.851, blue: 0.478))

                Spacer()
            }
            .padding(28)
        }
        .preferredColorScheme(.light)
        .onAppear { date = initial }
        .presentationDetents([.large])
    }
}
