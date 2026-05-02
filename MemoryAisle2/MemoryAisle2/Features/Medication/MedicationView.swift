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
    @Environment(AppState.self) private var appState
    @Query(sort: \MedicationProfile.startDate, order: .reverse) private var medications: [MedicationProfile]
    @Query private var profiles: [UserProfile]

    @State private var editingField: EditingField?
    @State private var doseReminderEnabledLocal: Bool = false
    @State private var hasInitializedDoseReminderState = false

    private var med: MedicationProfile? { medications.first }

    /// Resolves the current signed-in user's profile. Prefers the
    /// userId-scoped match (post-migration normal case) and falls back to
    /// `profiles.first` for legacy rows whose userId hasn't been stamped
    /// yet — this keeps the screen useful for users who haven't re-
    /// onboarded since the userId field shipped.
    private var profile: UserProfile? {
        profiles.first(where: { $0.userId == appState.cognitoUserId })
            ?? profiles.first
    }

    /// Non-GLP-1 users (no medication of any flavor recorded) see a slimmer
    /// "Allergies & Restrictions" version of this surface — same canvas,
    /// just the dietary chip grid. The medication-specific sections,
    /// safety note, and footer are hidden for them.
    private var hasMedicationConfigured: Bool {
        profile?.medicationModality != nil
            || med != nil
            || profile?.medication != nil
    }

    private enum EditingField: Identifiable {
        case providerName, providerPhone, providerAddress
        case pharmacyName, pharmacyPhone, pharmacyAddress
        case refillDate
        case dose
        case doseReminderTime

        var id: String { String(describing: self) }
    }

    var body: some View {
        ZStack {
            EditorialBackground(mode: mode)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    HairlineDivider().padding(.vertical, 8)

                    if hasMedicationConfigured {
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
                        noMedicationState
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
        .onAppear {
            // Lazy-create the MedicationProfile for users who completed
            // onboarding before MedicationProfile rows existed (or before
            // their device had one). Without this, every editor below
            // writes through `med?.field = value` which silently no-ops
            // when `med` is nil — provider/pharmacy/refill edits would
            // appear to save but disappear on next view.
            ensureMedicationProfile()

            guard !hasInitializedDoseReminderState else { return }
            hasInitializedDoseReminderState = true
            doseReminderEnabledLocal = doseReminderEnabled
        }
        .onChange(of: doseReminderEnabledLocal) { _, newValue in
            setDoseReminderEnabled(newValue)
            if newValue {
                Task { await scheduleDoseReminderIfPossible() }
            } else {
                NotificationScheduler.clearDoseReminders()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 56)
            Image(systemName: hasMedicationConfigured ? "cross.case" : "leaf")
                .font(.system(size: 22))
                .foregroundStyle(Theme.Editorial.onSurface)
                .padding(.bottom, 14)
            Text("Medication & Allergies")
                .font(.system(size: 26, weight: .regular, design: .serif))
                .tracking(0.6)
                .foregroundStyle(Theme.Editorial.onSurface)
            Text(hasMedicationConfigured
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

            HairlineDivider().padding(.vertical, 8)
            sectionLabel("DOSE REMINDER")
            HStack {
                Text("Enabled")
                    .font(Theme.Editorial.Typography.body())
                    .foregroundStyle(Theme.Editorial.onSurface.opacity(0.7))
                Spacer()
                Toggle("", isOn: $doseReminderEnabledLocal)
                    .labelsHidden()
                    .tint(Color(red: 0.961, green: 0.851, blue: 0.478))
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            .overlay(alignment: .top) {
                Rectangle().fill(Theme.Editorial.onSurface.opacity(0.08)).frame(height: 0.5)
            }

            if doseReminderEnabledLocal {
                ledgerEditableRow(
                    label: "Time",
                    value: doseReminderTimeLabel,
                    editing: .doseReminderTime
                )
            }
        }
    }

    private var providerSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("II · PROVIDER")
            ledgerEditableRow(
                label: "Physician",
                value: med?.providerName ?? "—",
                editing: .providerName
            )
            ledgerEditableRow(
                label: "Phone",
                value: med?.providerPhone ?? "—",
                editing: .providerPhone,
                callable: med?.providerPhone
            )
            ledgerEditableRow(
                label: "Address",
                value: providerAddress ?? "—",
                editing: .providerAddress
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
            ledgerEditableRow(
                label: "Address",
                value: pharmacyAddress ?? "—",
                editing: .pharmacyAddress
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
            sectionLabel(hasMedicationConfigured ? "VI · ALLERGIES & RESTRICTIONS" : "RESTRICTIONS")
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
                guard let m = ensureMedicationProfile() else { return }
                m.providerName = value.isEmpty ? nil : value
                try? modelContext.save()
            }
        case .providerPhone:
            TextEditorSheet(title: "PROVIDER PHONE",
                            initial: med?.providerPhone ?? "",
                            placeholder: "555 123 4567",
                            keyboard: .phonePad) { value in
                guard let m = ensureMedicationProfile() else { return }
                m.providerPhone = value.isEmpty ? nil : value
                try? modelContext.save()
            }
        case .providerAddress:
            TextEditorSheet(title: "PROVIDER ADDRESS",
                            initial: providerAddress ?? "",
                            placeholder: "Street, City, State") { value in
                _ = ensureMedicationProfile()
                setNoteValue(key: "providerAddress", value: value)
                try? modelContext.save()
            }
        case .pharmacyName:
            TextEditorSheet(title: "PHARMACY NAME",
                            initial: med?.pharmacyName ?? "",
                            placeholder: "Pharmacy + location") { value in
                guard let m = ensureMedicationProfile() else { return }
                m.pharmacyName = value.isEmpty ? nil : value
                try? modelContext.save()
            }
        case .pharmacyPhone:
            TextEditorSheet(title: "PHARMACY PHONE",
                            initial: med?.pharmacyPhone ?? "",
                            placeholder: "555 123 4567",
                            keyboard: .phonePad) { value in
                guard let m = ensureMedicationProfile() else { return }
                m.pharmacyPhone = value.isEmpty ? nil : value
                try? modelContext.save()
            }
        case .pharmacyAddress:
            TextEditorSheet(title: "PHARMACY ADDRESS",
                            initial: pharmacyAddress ?? "",
                            placeholder: "Street, City, State") { value in
                _ = ensureMedicationProfile()
                setNoteValue(key: "pharmacyAddress", value: value)
                try? modelContext.save()
            }
        case .refillDate:
            DatePickerSheet(
                title: "REFILL DUE",
                initial: med?.refillDueDate ?? .now
            ) { date in
                guard let m = ensureMedicationProfile() else { return }
                m.refillDueDate = date
                try? modelContext.save()
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
        case .doseReminderTime:
            TimePickerSheet(
                title: "DOSE REMINDER TIME",
                initial: doseReminderTime ?? defaultDoseReminderTime
            ) { date in
                setDoseReminderTime(date)
                Task { await scheduleDoseReminderIfPossible() }
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

    // MARK: - Lazy MedicationProfile creation

    /// Promotes the user's onboarding-captured medication answers
    /// (which live on `UserProfile`) into a real `MedicationProfile`
    /// row the first time this screen appears, so editor sheets that
    /// write through `med?.field = value` actually persist.
    ///
    /// No-op when:
    ///   - a MedicationProfile already exists, or
    ///   - the user isn't on a medication (no `profile.medication` /
    ///     `profile.medicationModality` from onboarding) — those users
    ///     see the slim allergies-only variant of this surface and
    ///     never reach the editor sheets.
    @discardableResult
    private func ensureMedicationProfile() -> MedicationProfile? {
        if let existing = med { return existing }
        guard let profile,
              let medication = profile.medication,
              let modality = profile.medicationModality
        else { return nil }
        let startDate = (UserDefaults.standard.object(forKey: "medicationStartDate") as? Date) ?? .now
        let new = MedicationProfile(
            medication: medication,
            modality: modality,
            doseAmount: profile.doseAmount ?? "",
            startDate: startDate,
            injectionDay: profile.injectionDay,
            pillTime: profile.pillTime
        )
        modelContext.insert(new)
        try? modelContext.save()
        return new
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

// MARK: - Notes-backed fields (addresses)

private extension MedicationView {
    var providerAddress: String? { noteValue(for: "providerAddress") }
    var pharmacyAddress: String? { noteValue(for: "pharmacyAddress") }
    var doseReminderEnabled: Bool { (noteValue(for: "doseReminderEnabled") ?? "") == "true" }

    var doseReminderTime: Date? {
        guard let raw = noteValue(for: "doseReminderTime") else { return nil }
        let parts = raw.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]),
              (0...23).contains(hour),
              (0...59).contains(minute) else { return nil }

        var comps = Calendar.current.dateComponents([.year, .month, .day], from: .now)
        comps.hour = hour
        comps.minute = minute
        return Calendar.current.date(from: comps)
    }

    var defaultDoseReminderTime: Date {
        // Prefer pill time for oral meds; otherwise default to 9:00 AM today.
        if let t = med?.pillTime ?? profile?.pillTime {
            var comps = Calendar.current.dateComponents([.year, .month, .day], from: .now)
            let time = Calendar.current.dateComponents([.hour, .minute], from: t)
            comps.hour = time.hour ?? 9
            comps.minute = time.minute ?? 0
            return Calendar.current.date(from: comps) ?? .now
        }
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: .now)
        comps.hour = 9
        comps.minute = 0
        return Calendar.current.date(from: comps) ?? .now
    }

    var doseReminderTimeLabel: String {
        let date = doseReminderTime ?? defaultDoseReminderTime
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: date).uppercased()
    }

    func setDoseReminderEnabled(_ enabled: Bool) {
        setNoteValue(key: "doseReminderEnabled", value: enabled ? "true" : "")
    }

    func setDoseReminderTime(_ date: Date) {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        let hour = comps.hour ?? 9
        let minute = comps.minute ?? 0
        setNoteValue(key: "doseReminderTime", value: "\(hour):\(minute)")
    }

    func scheduleDoseReminderIfPossible() async {
        guard doseReminderEnabledLocal else { return }
        guard let med else { return }

        let permitted = await NotificationScheduler.requestPermission()
        guard permitted else { return }

        let time = doseReminderTime ?? defaultDoseReminderTime
        let comps = Calendar.current.dateComponents([.hour, .minute], from: time)
        let hour = comps.hour ?? 9
        let minute = comps.minute ?? 0

        switch med.modality {
        case .injectable:
            guard let weekday = med.injectionDay ?? profile?.injectionDay else { return }
            let dose = (med.doseAmount.isEmpty ? nil : med.doseAmount)
                ?? (profile?.doseAmount?.isEmpty == false ? profile?.doseAmount : nil)
            let body = [med.medication.rawValue, dose].compactMap { $0 }.joined(separator: " · ")
            NotificationScheduler.scheduleDoseReminderWeekly(
                weekday: weekday,
                hour: hour,
                minute: minute,
                body: body.isEmpty ? "Time for your weekly dose." : body
            )
        case .oralWithFasting, .oralNoFasting:
            let dose = (med.doseAmount.isEmpty ? nil : med.doseAmount)
                ?? (profile?.doseAmount?.isEmpty == false ? profile?.doseAmount : nil)
            let body = [med.medication.rawValue, dose].compactMap { $0 }.joined(separator: " · ")
            NotificationScheduler.scheduleDoseReminderDaily(
                hour: hour,
                minute: minute,
                body: body.isEmpty ? "Time for your dose." : body
            )
        }
    }

    func noteValue(for key: String) -> String? {
        guard let notes = med?.notes, !notes.isEmpty else { return nil }
        let lines = notes.split(separator: "\n", omittingEmptySubsequences: true)
        let prefix = "\(key):"
        for lineSub in lines {
            let line = String(lineSub)
            guard line.hasPrefix(prefix) else { continue }
            let raw = line.dropFirst(prefix.count)
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        return nil
    }

    func setNoteValue(key: String, value: String) {
        guard let med else { return }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        var map: [String: String] = [:]

        if let notes = med.notes, !notes.isEmpty {
            for lineSub in notes.split(separator: "\n", omittingEmptySubsequences: true) {
                let line = String(lineSub)
                guard let idx = line.firstIndex(of: ":") else { continue }
                let k = String(line[..<idx]).trimmingCharacters(in: .whitespacesAndNewlines)
                let v = String(line[line.index(after: idx)...]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !k.isEmpty, !v.isEmpty { map[k] = v }
            }
        }

        if trimmed.isEmpty {
            map.removeValue(forKey: key)
        } else {
            map[key] = trimmed
        }

        let serialized = map
            .sorted(by: { $0.key < $1.key })
            .map { "\($0.key): \($0.value)" }
            .joined(separator: "\n")

        med.notes = serialized.isEmpty ? nil : serialized
    }
}
