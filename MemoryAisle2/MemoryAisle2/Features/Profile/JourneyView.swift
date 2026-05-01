@preconcurrency import PhotosUI
import SwiftData
import SwiftUI

/// Editorial Journey + Progress consolidation per
/// `/Desktop/memoryaisle_journey_mock.html`. Replaces the legacy
/// `JourneyProfileView` and `ProgressDashboardView` (both kept on disk
/// but unreachable). Pro-only via `MainTabView.proGatedDestinations`.
///
/// Section order:
///   - Identity hero (square avatar + name + day/week + medication)
///   - Editorial intro (three-line italic display, computed deltas)
///   - I · The Arc (start/now photos + weight chart)
///   - II · Body Composition (lean / body fat / weight + projection)
///   - III · This Week (protein-hit / hydration / training)
///   - IV · Medication (cycle phase, weeks, next dose) — conditional
///   - V · Targets (editable steppers for cal / protein / fiber / water)
///   - Mira's Note (closing editorial column, weekly cache)
///   - VI · Tools (weigh-in, GI tolerance, provider report)
///
/// All metrics computed locally; only Mira's Note hits Bedrock and only
/// once per ISO week (cached by `WeeklyNoteCache` in UserDefaults).
struct JourneyView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    @Query private var profiles: [UserProfile]
    @Query(sort: \NutritionLog.date, order: .reverse) private var logs: [NutritionLog]
    @Query(sort: \BodyComposition.date, order: .reverse) private var bodyComp: [BodyComposition]
    @Query(sort: \TrainingSession.date, order: .reverse) private var trainingSessions: [TrainingSession]

    @State private var healthKit = HealthKitManager()
    @State private var avatarPickerItem: PhotosPickerItem?
    @State private var avatarData: Data?
    @State private var showPhotoPicker = false

    @State private var showWeighIn = false
    @State private var showGITolerance = false
    @State private var showProviderReport = false

    @State private var miraNote: String?
    @State private var miraNoteLoading: Bool = false

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        ZStack {
            EditorialBackground(mode: appState.effectiveAppearanceMode)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    identityHero
                    editorialIntro
                    HairlineDivider().padding(.vertical, 8)

                    if !arcPhotos.isEmpty || !combinedWeightHistory.isEmpty {
                        arcSection
                        sectionDivider
                    }

                    if let latest = bodyComp.first {
                        bodyCompositionSection(latest)
                        sectionDivider
                    }

                    if !weekLogs.isEmpty || !weekTrainingSessions.isEmpty {
                        thisWeekSection
                        sectionDivider
                    }

                    if profile?.medication != nil {
                        medicationSection
                        sectionDivider
                    }

                    targetsSection
                    sectionDivider

                    miraNoteSection
                    sectionDivider

                    toolsSection
                    footer
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
        .sheet(isPresented: $showWeighIn) { PhotoCheckInView(mode: appState.effectiveAppearanceMode) }
        .sheet(isPresented: $showGITolerance) { GIToleranceView(mode: appState.effectiveAppearanceMode) }
        .sheet(isPresented: $showProviderReport) {
            ProviderReportView(mode: appState.effectiveAppearanceMode).biometricProtected()
        }
        .task {
            await loadAvatarFromProfile()
            await refreshMiraNoteIfStale()
        }
        .onChange(of: avatarPickerItem) { _, newItem in
            Task { await loadAvatar(from: newItem) }
        }
    }

    // MARK: - Done

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
        .accessibilityLabel("Done")
    }

    // MARK: - Identity hero

    private var identityHero: some View {
        HStack(alignment: .top, spacing: 16) {
            avatarSquare
                .frame(width: 88, height: 88)

            VStack(alignment: .leading, spacing: 6) {
                Text(profile?.name ?? "")
                    .font(.system(size: 24, weight: .regular, design: .serif))
                    .tracking(0.6)
                    .foregroundStyle(Theme.Editorial.onSurface)

                Text(dayWeekEyebrow)
                    .font(Theme.Editorial.Typography.caps(9, weight: .medium))
                    .tracking(2.8)
                    .foregroundStyle(Theme.Editorial.onSurfaceFaint)

                if let medLine {
                    Text(medLine)
                        .font(Theme.Editorial.Typography.caps(9, weight: .medium))
                        .tracking(2.4)
                        .foregroundStyle(Color(red: 0.961, green: 0.851, blue: 0.478))
                }
            }
            Spacer()
        }
        .padding(.top, 8)
        .padding(.bottom, 18)
    }

    /// Button + .photosPicker modifier rather than PhotosPicker(label:) so
    /// the label closure stays MainActor-isolated. The PhotosPicker init
    /// closure is inferred Sendable under Swift 6 strict concurrency,
    /// which can't reach Theme tokens.
    private var avatarSquare: some View {
        Button {
            showPhotoPicker = true
        } label: {
            ZStack {
                if let avatarData, let uiImage = UIImage(data: avatarData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    LinearGradient(
                        colors: [
                            Theme.Editorial.onSurface.opacity(0.12),
                            Theme.Editorial.onSurface.opacity(0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Image(systemName: "person")
                        .font(.system(size: 32, weight: .light))
                        .foregroundStyle(Theme.Editorial.onSurface.opacity(0.7))
                }
            }
            .frame(width: 88, height: 88)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Theme.Editorial.onSurface.opacity(0.25), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Profile photo, tap to change")
        .photosPicker(isPresented: $showPhotoPicker, selection: $avatarPickerItem, matching: .images)
    }

    private var dayWeekEyebrow: String {
        "DAY \(RomanNumeral.string(from:dayCount)) · WEEK \(RomanNumeral.string(from:max(1, (dayCount - 1) / 7 + 1)))"
    }

    private var medLine: String? {
        guard let med = profile?.medication?.rawValue, !med.isEmpty else { return nil }
        if let dose = profile?.doseAmount, !dose.isEmpty {
            return "\(med.uppercased()) · \(dose.uppercased())"
        }
        return med.uppercased()
    }

    // MARK: - Editorial intro

    private var editorialIntro: some View {
        let lines = introLines
        return VStack(alignment: .leading, spacing: 0) {
            Text(lines.0)
                .font(.system(size: 32, weight: .light, design: .serif))
                .foregroundStyle(Theme.Editorial.onSurface)
            Text(lines.1)
                .font(.system(size: 32, weight: .light, design: .serif))
                .italic()
                .foregroundStyle(Theme.Editorial.onSurface)
            Text(lines.2)
                .font(.system(size: 32, weight: .light, design: .serif))
                .foregroundStyle(Theme.Editorial.onSurface)
        }
        .lineSpacing(2)
        .padding(.bottom, 14)
    }

    /// Three-line editorial intro built from real metrics. Always frames
    /// the trajectory positively — never quantifies a gap (per the
    /// weight-loss tone rule). When there's no data yet, falls back to a
    /// gentle invitation rather than a stat dump.
    private var introLines: (String, String, String) {
        let day = dayCount
        let dayLine = "Day \(EnglishNumber.word(from:day))."

        guard let weight = weightDelta else {
            return (dayLine, "Showing up,", "is the work.")
        }

        let absLbs = Int(abs(weight).rounded())
        if weight < 0 {
            return (dayLine, "\(EnglishNumber.word(from:absLbs)) pound\(absLbs == 1 ? "" : "s") down,", leanLine)
        } else if weight > 0 {
            return (dayLine, "Building base,", leanLine)
        } else {
            return (dayLine, "Holding steady,", leanLine)
        }
    }

    private var leanLine: String {
        guard let lean = leanDelta else { return "muscle kept." }
        return lean >= 0 ? "muscle kept." : "still building."
    }

    // MARK: - I · The Arc

    private var arcSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("I · THE ARC")

            if !arcPhotos.isEmpty {
                arcPhotoStrip
                    .padding(.bottom, 18)
            }

            if !combinedWeightHistory.isEmpty {
                arcChart
            }
        }
    }

    private var arcPhotoStrip: some View {
        let pair = arcPhotos
        return HStack(spacing: 12) {
            ForEach(pair, id: \.label) { photo in
                VStack(spacing: 8) {
                    photoSquare(data: photo.data, isCurrent: photo.isCurrent)
                    Text("\(Int(photo.weight)) lbs")
                        .font(.system(size: 14, weight: .regular, design: .serif))
                        .italic(photo.isCurrent)
                        .foregroundStyle(Theme.Editorial.onSurface)
                    Text(photo.dateCaps)
                        .font(Theme.Editorial.Typography.caps(9, weight: .medium))
                        .tracking(2.2)
                        .foregroundStyle(Theme.Editorial.onSurface.opacity(0.5))
                    Text(photo.label)
                        .font(Theme.Editorial.Typography.caps(8, weight: .semibold))
                        .tracking(2.8)
                        .foregroundStyle(
                            photo.isCurrent
                                ? Color(red: 0.961, green: 0.851, blue: 0.478)
                                : Theme.Editorial.onSurface.opacity(0.35)
                        )
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private func photoSquare(data: Data?, isCurrent: Bool) -> some View {
        ZStack {
            if let data, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(
                    colors: [
                        Theme.Editorial.onSurface.opacity(isCurrent ? 0.14 : 0.08),
                        Color.black.opacity(isCurrent ? 0.18 : 0.25)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                Image(systemName: "person")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(
                        Theme.Editorial.onSurface.opacity(isCurrent ? 0.7 : 0.4)
                    )
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(
                    isCurrent
                        ? Theme.Editorial.onSurface.opacity(0.45)
                        : Theme.Editorial.onSurface.opacity(0.18),
                    lineWidth: isCurrent ? 1.0 : 0.5
                )
        )
    }

    private var arcChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("WEIGHT · LBS · \(dayCount) DAYS")
                .font(Theme.Editorial.Typography.caps(9, weight: .medium))
                .tracking(2.4)
                .foregroundStyle(Theme.Editorial.onSurface.opacity(0.5))

            EditorialWeightChart(history: combinedWeightHistory)
                .frame(height: 110)

            HStack {
                Text("DAY 1")
                    .font(Theme.Editorial.Typography.caps(8, weight: .medium))
                    .tracking(2.2)
                    .foregroundStyle(Theme.Editorial.onSurface.opacity(0.4))
                Spacer()
                Text("DAY \(dayCount)")
                    .font(Theme.Editorial.Typography.caps(8, weight: .medium))
                    .tracking(2.2)
                    .foregroundStyle(Theme.Editorial.onSurface.opacity(0.4))
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 8)
    }

    // MARK: - II · Body Composition

    private func bodyCompositionSection(_ latest: BodyComposition) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("II · BODY COMPOSITION")

            HStack(spacing: 0) {
                bodyCompCell(
                    label: "LEAN",
                    value: "\(Int(latest.computedLeanMass.rounded()))",
                    unit: "LBS",
                    delta: leanDelta,
                    deltaSuffix: ""
                )
                Rectangle()
                    .fill(Theme.Editorial.onSurface.opacity(0.12))
                    .frame(width: 0.5)
                    .frame(maxHeight: .infinity)
                bodyCompCell(
                    label: "BODY FAT",
                    value: latest.bodyFatPercent.map { String(format: "%.0f", $0) } ?? "—",
                    unit: latest.bodyFatPercent != nil ? "%" : "TODAY",
                    delta: bodyFatDelta,
                    deltaSuffix: "",
                    showAsPercentSuffix: latest.bodyFatPercent != nil
                )
                Rectangle()
                    .fill(Theme.Editorial.onSurface.opacity(0.12))
                    .frame(width: 0.5)
                    .frame(maxHeight: .infinity)
                bodyCompCell(
                    label: "WEIGHT",
                    value: "\(Int(latest.weightLbs.rounded()))",
                    unit: "LBS",
                    delta: weightDelta,
                    deltaSuffix: ""
                )
            }
            .padding(.vertical, 6)

            if bodyComp.count >= 2, let first = bodyComp.last {
                Text("SINCE FIRST CHECK-IN · \(dateCapsFormat(first.date))")
                    .font(Theme.Editorial.Typography.caps(9, weight: .medium))
                    .tracking(2.2)
                    .foregroundStyle(Theme.Editorial.onSurface.opacity(0.4))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 6)
            }

            if let projection = goalProjectionLine {
                Text(projection)
                    .font(Theme.Editorial.Typography.caps(10, weight: .medium))
                    .tracking(2.8)
                    .foregroundStyle(Color(red: 0.961, green: 0.851, blue: 0.478).opacity(0.85))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 8)
                    .padding(.bottom, 6)
            }
        }
    }

    @ViewBuilder
    private func bodyCompCell(
        label: String,
        value: String,
        unit: String,
        delta: Double?,
        deltaSuffix: String,
        showAsPercentSuffix: Bool = false
    ) -> some View {
        VStack(spacing: 6) {
            Text(label)
                .font(Theme.Editorial.Typography.caps(9, weight: .medium))
                .tracking(2.8)
                .foregroundStyle(Theme.Editorial.onSurface.opacity(0.55))

            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(value)
                    .font(.system(size: 28, weight: .regular, design: .serif))
                if showAsPercentSuffix {
                    Text("%")
                        .font(.system(size: 16, weight: .regular, design: .serif))
                        .foregroundStyle(Theme.Editorial.onSurface.opacity(0.6))
                }
            }
            .foregroundStyle(Theme.Editorial.onSurface)

            Text(unit)
                .font(Theme.Editorial.Typography.caps(9, weight: .medium))
                .tracking(1.8)
                .foregroundStyle(Theme.Editorial.onSurface.opacity(0.5))

            if let delta {
                Text(deltaString(delta))
                    .font(Theme.Editorial.Typography.caps(9, weight: .medium))
                    .tracking(2.2)
                    .foregroundStyle(Color(red: 0.961, green: 0.851, blue: 0.478).opacity(0.95))
            } else {
                Text(" ")
                    .font(Theme.Editorial.Typography.caps(9, weight: .medium))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func deltaString(_ delta: Double) -> String {
        let sign = delta > 0 ? "+" : (delta < 0 ? "−" : "±")
        return "\(sign)\(String(format: "%.1f", abs(delta)))"
    }

    /// Computed only when there's enough signal: at least one delta
    /// magnitude AND a goal weight set. Pure motivation, never a doom
    /// estimate — if the trajectory points away from the goal we hide
    /// the line rather than say "goal slipping."
    private var goalProjectionLine: String? {
        guard let goal = profile?.goalWeightLbs,
              let latest = bodyComp.first?.weightLbs ?? combinedWeightHistory.last?.value,
              let weeklyRate = weeklyWeightRate,
              weeklyRate < 0 else {
            return nil
        }
        let remaining = latest - goal
        guard remaining > 0.5 else { return nil }
        let weeksNeeded = max(1, Int((remaining / abs(weeklyRate)).rounded()))
        let goalWeek = currentWeekIndex + weeksNeeded
        return "AT THIS PACE · GOAL IN WEEK \(RomanNumeral.string(from:goalWeek))"
    }

    // MARK: - III · This Week

    private var thisWeekSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("III · THIS WEEK")

            HStack(spacing: 0) {
                weekStatCell(label: "PROTEIN HIT",
                             value: "\(proteinHitRate)",
                             unit: "ON TARGET",
                             showPercent: true)
                Rectangle()
                    .fill(Theme.Editorial.onSurface.opacity(0.12))
                    .frame(width: 0.5)
                    .frame(maxHeight: .infinity)
                weekStatCell(label: "HYDRATION",
                             value: "\(avgHydration)",
                             unit: "AVG VS TARGET",
                             showPercent: true)
                Rectangle()
                    .fill(Theme.Editorial.onSurface.opacity(0.12))
                    .frame(width: 0.5)
                    .frame(maxHeight: .infinity)
                weekStatCell(label: "TRAINING",
                             value: "\(weekTrainingSessions.count)",
                             unit: weekTrainingSessions.count == 1 ? "SESSION" : "SESSIONS",
                             showPercent: false)
            }
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private func weekStatCell(label: String, value: String, unit: String, showPercent: Bool) -> some View {
        VStack(spacing: 6) {
            Text(label)
                .font(Theme.Editorial.Typography.caps(9, weight: .medium))
                .tracking(2.8)
                .foregroundStyle(Theme.Editorial.onSurface.opacity(0.55))

            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(value)
                    .font(.system(size: 28, weight: .regular, design: .serif))
                if showPercent {
                    Text("%")
                        .font(.system(size: 16, weight: .regular, design: .serif))
                        .foregroundStyle(Theme.Editorial.onSurface.opacity(0.6))
                }
            }
            .foregroundStyle(Theme.Editorial.onSurface)

            Text(unit)
                .font(Theme.Editorial.Typography.caps(9, weight: .medium))
                .tracking(1.8)
                .foregroundStyle(Theme.Editorial.onSurface.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - IV · Medication

    private var medicationSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("IV · MEDICATION")

            VStack(alignment: .leading, spacing: 4) {
                Text("GLP-1 therapy")
                    .font(.system(size: 22, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(Theme.Editorial.onSurface)
                Text(medicationMeta)
                    .font(Theme.Editorial.Typography.caps(10, weight: .medium))
                    .tracking(2.4)
                    .foregroundStyle(Theme.Editorial.onSurface.opacity(0.55))
            }
            .padding(.vertical, 4)
            .padding(.bottom, 10)

            if let phase = cyclePhaseLine {
                medRow(label: "Cycle Phase", value: phase)
            }
            medRow(label: "Weeks On", value: RomanNumeral.string(from:medicationWeeks))
            if let next = nextDoseLine {
                medRow(label: "Next Dose", value: next)
            }
        }
    }

    private var medicationMeta: String {
        guard let med = profile?.medication?.rawValue.uppercased() else { return "" }
        var parts = [med]
        if let dose = profile?.doseAmount, !dose.isEmpty {
            parts.append(dose.uppercased())
        }
        if let modality = profile?.medicationModality {
            switch modality {
            case .injectable: parts.append("WEEKLY")
            case .oralWithFasting, .oralNoFasting: parts.append("DAILY")
            }
        }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private func medRow(label: String, value: String) -> some View {
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
        .padding(.vertical, 8)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.Editorial.onSurface.opacity(0.08)).frame(height: 0.5)
        }
    }

    // MARK: - V · Targets

    private var targetsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("V · TARGETS")
                    .font(Theme.Editorial.Typography.caps(9, weight: .medium))
                    .tracking(2.8)
                    .foregroundStyle(Theme.Editorial.onSurfaceMuted)
                Text("ADJUST WITH THE STEPPERS")
                    .font(Theme.Editorial.Typography.caps(9, weight: .regular))
                    .tracking(2.2)
                    .foregroundStyle(Theme.Editorial.onSurface.opacity(0.4))
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 4)

            targetRow(
                title: "Calories",
                helper: "DAILY TARGET",
                value: profile?.calorieTarget ?? 1800,
                step: 50,
                range: 1200...3500,
                set: { profile?.calorieTarget = $0 }
            )
            targetRow(
                title: "Protein",
                helper: "GRAMS · LEAN-MASS ANCHOR",
                value: profile?.proteinTargetGrams ?? 140,
                step: 5,
                range: 60...250,
                set: { profile?.proteinTargetGrams = $0 }
            )
            targetRow(
                title: "Fiber",
                helper: "GRAMS",
                value: profile?.fiberTargetGrams ?? 25,
                step: 1,
                range: 10...60,
                set: { profile?.fiberTargetGrams = $0 }
            )
            waterTargetRow
        }
    }

    @ViewBuilder
    private func targetRow(
        title: String,
        helper: String,
        value: Int,
        step: Int,
        range: ClosedRange<Int>,
        set: @escaping (Int) -> Void
    ) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.Editorial.onSurface)
                Text(helper)
                    .font(Theme.Editorial.Typography.caps(9, weight: .medium))
                    .tracking(1.8)
                    .foregroundStyle(Theme.Editorial.onSurface.opacity(0.5))
            }
            Spacer()
            HStack(spacing: 10) {
                stepperButton(symbol: "minus") {
                    set(max(range.lowerBound, value - step))
                }
                Text(value.formatted(.number))
                    .font(.system(size: 22, weight: .regular, design: .serif))
                    .foregroundStyle(Theme.Editorial.onSurface)
                    .frame(minWidth: 64)
                    .multilineTextAlignment(.center)
                stepperButton(symbol: "plus") {
                    set(min(range.upperBound, value + step))
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.Editorial.onSurface.opacity(0.08)).frame(height: 0.5)
        }
    }

    private var waterTargetRow: some View {
        let current = profile?.waterTargetLiters ?? 2.5
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Water")
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.Editorial.onSurface)
                Text("LITERS")
                    .font(Theme.Editorial.Typography.caps(9, weight: .medium))
                    .tracking(1.8)
                    .foregroundStyle(Theme.Editorial.onSurface.opacity(0.5))
            }
            Spacer()
            HStack(spacing: 10) {
                stepperButton(symbol: "minus") {
                    profile?.waterTargetLiters = max(1.0, ((current * 10).rounded() - 1) / 10)
                }
                Text(String(format: "%.1f", current))
                    .font(.system(size: 22, weight: .regular, design: .serif))
                    .foregroundStyle(Theme.Editorial.onSurface)
                    .frame(minWidth: 64)
                    .multilineTextAlignment(.center)
                stepperButton(symbol: "plus") {
                    profile?.waterTargetLiters = min(6.0, ((current * 10).rounded() + 1) / 10)
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.Editorial.onSurface.opacity(0.08)).frame(height: 0.5)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.Editorial.onSurface.opacity(0.08)).frame(height: 0.5)
        }
    }

    @ViewBuilder
    private func stepperButton(symbol: String, action: @escaping () -> Void) -> some View {
        Button {
            HapticManager.selection()
            action()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.Editorial.onSurface)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Theme.Editorial.onSurface.opacity(0.08)))
                .overlay(Circle().stroke(Theme.Editorial.onSurface.opacity(0.2), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(symbol == "minus" ? "Decrease" : "Increase")
    }

    // MARK: - Mira's Note

    private var miraNoteSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                HStack(spacing: 10) {
                    miraBars
                    Text("MIRA'S NOTE")
                        .font(Theme.Editorial.Typography.caps(10, weight: .semibold))
                        .tracking(3.2)
                        .foregroundStyle(Theme.Editorial.onSurface.opacity(0.7))
                }
                Spacer()
                Text("WEEK \(RomanNumeral.string(from:currentWeekIndex))")
                    .font(Theme.Editorial.Typography.caps(9, weight: .medium))
                    .tracking(2.8)
                    .foregroundStyle(Theme.Editorial.onSurface.opacity(0.45))
            }
            .padding(.top, 14)
            .padding(.bottom, 14)

            if miraNoteLoading && miraNote == nil {
                ProgressView()
                    .tint(Theme.Editorial.onSurface)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else {
                Text(attributedMiraNote)
                    .font(.system(size: 17, weight: .light, design: .serif))
                    .foregroundStyle(Theme.Editorial.onSurface)
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("REFRESHES MONDAY MORNING")
                .font(Theme.Editorial.Typography.caps(9, weight: .medium))
                .tracking(2.8)
                .foregroundStyle(Theme.Editorial.onSurface.opacity(0.4))
                .padding(.top, 14)
                .padding(.bottom, 8)
        }
    }

    private var miraBars: some View {
        HStack(alignment: .center, spacing: 2.5) {
            Capsule().fill(Theme.Editorial.onSurface).frame(width: 1.4, height: 8)
            Capsule().fill(Theme.Editorial.onSurface).frame(width: 1.4, height: 12)
            Capsule().fill(Theme.Editorial.onSurface).frame(width: 1.4, height: 10)
            Capsule().fill(Theme.Editorial.onSurface).frame(width: 1.4, height: 5)
        }
        .frame(width: 16, height: 14)
    }

    private var fallbackNote: String {
        "A new chapter is starting. Log a meal or do a check-in this week and I'll have something for you here on Monday."
    }

    /// Renders Mira's note through Markdown so any `*italic*` Bedrock slips
    /// past the prompt rule shows up as actual italic instead of literal
    /// asterisks. Preserves whitespace so paragraph breaks survive.
    /// Falls back to a plain attributed string on parse failure.
    private var attributedMiraNote: AttributedString {
        let raw = miraNote ?? fallbackNote
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
        if let attr = try? AttributedString(markdown: raw, options: options) {
            return attr
        }
        return AttributedString(raw)
    }

    // MARK: - VI · Tools

    private var toolsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("VI · TOOLS")

            toolRow(
                icon: "camera",
                title: "Weekly Weigh-In",
                subtitle: "PHOTO · WEIGHT · LEAN MASS"
            ) {
                showWeighIn = true
            }
            rowDivider
            toolRow(
                icon: "leaf",
                title: "GI Tolerance",
                subtitle: "FOODS · SYMPTOMS · RISK"
            ) {
                showGITolerance = true
            }
            rowDivider
            toolRow(
                icon: "doc.text",
                title: "Provider Report",
                subtitle: "WEEKLY SUMMARY · PDF"
            ) {
                showProviderReport = true
            }
        }
    }

    @ViewBuilder
    private func toolRow(icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button {
            HapticManager.light()
            action()
        } label: {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.Editorial.onSurface)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.Editorial.onSurface)
                    Text(subtitle)
                        .font(Theme.Editorial.Typography.caps(9, weight: .medium))
                        .tracking(1.6)
                        .foregroundStyle(Theme.Editorial.onSurface.opacity(0.5))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.Editorial.onSurface.opacity(0.4))
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    // MARK: - Section primitives

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

    private var rowDivider: some View {
        Rectangle()
            .fill(Theme.Editorial.onSurface.opacity(0.08))
            .frame(height: 0.5)
            .padding(.horizontal, 4)
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

    // MARK: - Computed metrics

    private var dayCount: Int {
        let start = profile?.createdAt ?? bodyComp.last?.date ?? .now
        let days = Calendar.current.dateComponents([.day], from: start, to: .now).day ?? 0
        return max(1, days + 1)
    }

    private var currentWeekIndex: Int {
        max(1, (dayCount - 1) / 7 + 1)
    }

    private var combinedWeightHistory: [(date: Date, value: Double)] {
        let manual = bodyComp.map { (date: $0.date, value: $0.weightLbs) }
        let merged = manual + healthKit.weightHistory
        return merged.sorted { $0.date < $1.date }
    }

    /// Negative = lost weight. Positive = gained. nil if not enough samples.
    private var weightDelta: Double? {
        let history = combinedWeightHistory
        guard let first = history.first, let last = history.last,
              first.date != last.date else {
            return nil
        }
        return last.value - first.value
    }

    private var leanDelta: Double? {
        guard bodyComp.count >= 2,
              let first = bodyComp.last,
              let latest = bodyComp.first else {
            return nil
        }
        return latest.computedLeanMass - first.computedLeanMass
    }

    private var bodyFatDelta: Double? {
        guard bodyComp.count >= 2,
              let first = bodyComp.last?.bodyFatPercent,
              let latest = bodyComp.first?.bodyFatPercent else {
            return nil
        }
        return latest - first
    }

    private var weeklyWeightRate: Double? {
        guard let delta = weightDelta else { return nil }
        let weeks = max(1.0, Double(dayCount) / 7.0)
        return delta / weeks
    }

    private var weekLogs: [NutritionLog] {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        return logs.filter { $0.date > weekAgo }
    }

    private var weekTrainingSessions: [TrainingSession] {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        return trainingSessions.filter { $0.date >= weekAgo }
    }

    private var proteinHitRate: Int {
        guard !weekLogs.isEmpty, let target = profile?.proteinTargetGrams else { return 0 }
        let hits = weekLogs.filter { $0.proteinGrams >= Double(target) * 0.9 }.count
        return (hits * 100) / weekLogs.count
    }

    private var avgHydration: Int {
        guard !weekLogs.isEmpty, let target = profile?.waterTargetLiters, target > 0 else { return 0 }
        let avg = weekLogs.reduce(0.0) { $0 + $1.waterLiters } / Double(weekLogs.count)
        return min(100, Int((avg / target) * 100))
    }

    private var medicationWeeks: Int {
        guard let medStart = UserDefaults.standard.object(forKey: "medicationStartDate") as? Date else {
            return 1
        }
        let days = Calendar.current.dateComponents([.day], from: medStart, to: .now).day ?? 0
        return max(1, (days / 7) + 1)
    }

    private var cyclePhaseLine: String? {
        guard let day = profile?.injectionDay else { return nil }
        let phase = InjectionCycleEngine.currentPhase(injectionDay: day)
        let dayOfCycle = ((Calendar.current.component(.weekday, from: .now) - day + 7) % 7) + 1
        return "\(phase.rawValue.uppercased()) · DAY \(RomanNumeral.string(from:dayOfCycle)) OF VII"
    }

    private var nextDoseLine: String? {
        guard let day = profile?.injectionDay else { return nil }
        let cal = Calendar.current
        let today = cal.component(.weekday, from: .now)
        let daysUntil = (day - today + 7) % 7
        let target = cal.date(byAdding: .day, value: daysUntil == 0 ? 7 : daysUntil, to: .now) ?? .now
        let f = DateFormatter()
        f.dateFormat = "EEE"
        let weekday = f.string(from: target).uppercased()
        let monthDay = "\(RomanNumeral.string(from:cal.component(.day, from: target))) · \(RomanNumeral.string(from:cal.component(.month, from: target)))"
        return "\(weekday) · \(monthDay)"
    }

    /// Two photos to show in The Arc: the very first BodyComposition with
    /// a photo, and the latest BodyComposition with a photo. Hides the
    /// strip entirely when neither has photo data.
    private var arcPhotos: [ArcPhoto] {
        let withPhotos = bodyComp.filter { $0.photoData != nil }
        guard let first = withPhotos.last, let latest = withPhotos.first else {
            return []
        }
        if first.id == latest.id {
            return [
                ArcPhoto(
                    label: "STARTED",
                    weight: first.weightLbs,
                    dateCaps: dateCapsFormat(first.date),
                    data: first.photoData,
                    isCurrent: false
                )
            ]
        }
        return [
            ArcPhoto(
                label: "STARTED",
                weight: first.weightLbs,
                dateCaps: dateCapsFormat(first.date),
                data: first.photoData,
                isCurrent: false
            ),
            ArcPhoto(
                label: "NOW",
                weight: latest.weightLbs,
                dateCaps: dateCapsFormat(latest.date),
                data: latest.photoData,
                isCurrent: true
            )
        ]
    }

    private struct ArcPhoto {
        let label: String
        let weight: Double
        let dateCaps: String
        let data: Data?
        let isCurrent: Bool
    }

    private func dateCapsFormat(_ date: Date) -> String {
        let cal = Calendar.current
        return "\(RomanNumeral.string(from:cal.component(.month, from: date))) · \(RomanNumeral.string(from:cal.component(.day, from: date))) · \(RomanNumeral.string(from:cal.component(.year, from: date)))"
    }

    // MARK: - Avatar

    /// Avatar persistence is local-only (Documents/journey_avatar.jpg) so it
    /// survives across UserProfile schema changes — UserProfile has no
    /// `avatarPath` field. UserDefaults flag tells us whether the user has
    /// ever set one so we don't blindly try to read a missing file.
    @MainActor
    private func loadAvatarFromProfile() async {
        guard avatarData == nil else { return }
        let url = avatarFileURL
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        avatarData = try? Data(contentsOf: url)
    }

    private func loadAvatar(from item: PhotosPickerItem?) async {
        guard let item, let data = try? await item.loadTransferable(type: Data.self) else {
            return
        }
        try? data.write(to: avatarFileURL)
        await MainActor.run { avatarData = data }
    }

    private var avatarFileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("journey_avatar.jpg")
    }

    // MARK: - Mira's Note refresh

    /// One Bedrock call per ISO week. Reads the cached note + week tag from
    /// UserDefaults; if the tag matches the current ISO (year, week), use
    /// the cache; otherwise generate a fresh note and cache it.
    @MainActor
    private func refreshMiraNoteIfStale() async {
        let cache = WeeklyNoteCache.read()
        let now = Date()
        let calendar = Calendar(identifier: .iso8601)
        let week = calendar.component(.weekOfYear, from: now)
        let year = calendar.component(.yearForWeekOfYear, from: now)

        if let cache, cache.year == year, cache.week == week {
            miraNote = cache.text
            return
        }

        guard !miraNoteLoading else { return }
        miraNoteLoading = true
        defer { miraNoteLoading = false }

        let prompt = WeeklyNoteService.buildPrompt(
            dayCount: dayCount,
            weekIndex: currentWeekIndex,
            weightDelta: weightDelta,
            leanDelta: leanDelta,
            proteinHitRate: weekLogs.isEmpty ? nil : proteinHitRate,
            isOnGLP1: profile?.medication != nil
        )

        do {
            let api = MiraAPIClient()
            let reply = try await api.send(message: prompt, context: nil)
            let trimmed = reply.trimmingCharacters(in: .whitespacesAndNewlines)
            miraNote = trimmed
            WeeklyNoteCache.write(text: trimmed, year: year, week: week)
        } catch {
            // Silent failure — fallbackNote covers the empty state.
        }
    }
}

// MARK: - Weekly note caching

/// UserDefaults-backed cache for Mira's weekly note. Keyed by ISO week so
/// crossing midnight on Sunday automatically retires the cache. Stored as a
/// flat triple (year, week, text) — one call per surface, no model needed.
enum WeeklyNoteCache {
    private static let textKey = "journey.miraNote.text"
    private static let yearKey = "journey.miraNote.year"
    private static let weekKey = "journey.miraNote.week"

    struct Entry {
        let text: String
        let year: Int
        let week: Int
    }

    static func read() -> Entry? {
        let defaults = UserDefaults.standard
        guard let text = defaults.string(forKey: textKey), !text.isEmpty else { return nil }
        let year = defaults.integer(forKey: yearKey)
        let week = defaults.integer(forKey: weekKey)
        guard year > 0, week > 0 else { return nil }
        return Entry(text: text, year: year, week: week)
    }

    static func write(text: String, year: Int, week: Int) {
        let defaults = UserDefaults.standard
        defaults.set(text, forKey: textKey)
        defaults.set(year, forKey: yearKey)
        defaults.set(week, forKey: weekKey)
    }
}

// MARK: - Weekly note prompt

/// Builds the prompt for Mira's weekly note. Tone rules baked in here so a
/// single source of truth governs warmth/sensitivity. See feedback memory
/// `feedback_weight_loss_tone.md` for the underlying rule set.
enum WeeklyNoteService {
    static func buildPrompt(
        dayCount: Int,
        weekIndex: Int,
        weightDelta: Double?,
        leanDelta: Double?,
        proteinHitRate: Int?,
        isOnGLP1: Bool
    ) -> String {
        var lines: [String] = []
        lines.append("Write a short weekly note from Mira. Two paragraphs max, plain prose.")
        lines.append("")
        lines.append("Context (anonymized; do NOT echo numbers verbatim, talk about pattern):")
        lines.append("- Day \(dayCount), Week \(weekIndex) of the journey")
        if let weightDelta {
            let direction = weightDelta < 0 ? "down" : (weightDelta > 0 ? "up" : "steady")
            lines.append("- Weight trajectory overall: \(direction)")
        }
        if let leanDelta {
            let direction = leanDelta >= 0 ? "preserved or growing" : "still adjusting"
            lines.append("- Lean mass: \(direction)")
        }
        if let proteinHitRate {
            let pattern: String
            switch proteinHitRate {
            case 80...100: pattern = "stayed close to protein consistently"
            case 50..<80:  pattern = "showed up for protein on most days"
            default:       pattern = "had a tough week with protein"
            }
            lines.append("- Protein this week: \(pattern)")
        }
        lines.append("- On a GLP-1 medication: \(isOnGLP1 ? "yes" : "no")")
        lines.append("")
        lines.append("Tone rules (HARD constraints):")
        lines.append("- Warm, uplifting, present. Talk like someone who cares, not a coach.")
        lines.append("- Lead with what's working. Frame any soft spot as care, never correction.")
        lines.append("- Do NOT quantify partial compliance. Never say 'six of seven days' or '85%'. Talk in pattern language: 'stayed close to', 'held the line through', 'showed up'.")
        lines.append("- BANNED words: but, however, should, need to, issue, fail, missed, off-track, behind.")
        lines.append("- End with a presence-based italic line, like 'Keep going at your own pace. I'm in this with you.' Never advice.")
        lines.append("- Total length: 2 short paragraphs, ~50–70 words.")
        lines.append("- No markdown, no asterisks, no headers. Plain prose only.")
        lines.append("- Never echo the user's name.")
        lines.append("")
        lines.append("Begin the note now.")
        return lines.joined(separator: "\n")
    }
}

// MARK: - Editorial weight chart

/// Minimal SwiftUI line chart drawn on Canvas. Editorial style: white line,
/// hairline gridlines, gold dot on the latest sample. Pure rendering — the
/// merged manual + HealthKit data is computed by the caller.
struct EditorialWeightChart: View {
    let history: [(date: Date, value: Double)]

    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                guard history.count >= 2 else {
                    drawSingleSample(in: context, size: size)
                    return
                }

                let values = history.map(\.value)
                let lo = (values.min() ?? 0) - 1
                let hi = (values.max() ?? 1) + 1
                let range = max(0.1, hi - lo)
                let stepX = size.width / CGFloat(history.count - 1)

                // Hairline horizontal gridlines (top, mid, bottom).
                for fraction in [0.15, 0.5, 0.85] {
                    var line = Path()
                    let y = size.height * fraction
                    line.move(to: CGPoint(x: 0, y: y))
                    line.addLine(to: CGPoint(x: size.width, y: y))
                    context.stroke(
                        line,
                        with: .color(.white.opacity(0.12)),
                        style: StrokeStyle(lineWidth: 0.5, dash: [2, 4])
                    )
                }

                var path = Path()
                for (idx, sample) in history.enumerated() {
                    let x = CGFloat(idx) * stepX
                    let y = size.height - CGFloat((sample.value - lo) / range) * size.height
                    if idx == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                context.stroke(
                    path,
                    with: .color(.white),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
                )

                // Gold dot on the latest sample.
                if let last = history.last {
                    let x = size.width
                    let y = size.height - CGFloat((last.value - lo) / range) * size.height
                    let dot = Path(ellipseIn: CGRect(x: x - 4, y: y - 4, width: 8, height: 8))
                    context.fill(
                        dot,
                        with: .color(Color(red: 0.961, green: 0.851, blue: 0.478))
                    )
                }
            }
        }
    }

    private func drawSingleSample(in context: GraphicsContext, size: CGSize) {
        let dot = Path(ellipseIn: CGRect(x: size.width / 2 - 3, y: size.height / 2 - 3, width: 6, height: 6))
        context.fill(
            dot,
            with: .color(Color(red: 0.961, green: 0.851, blue: 0.478))
        )
    }
}

