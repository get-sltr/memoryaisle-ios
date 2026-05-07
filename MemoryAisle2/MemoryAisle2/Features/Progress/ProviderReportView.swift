import SwiftData
import SwiftUI

struct ProviderReportView: View {
    var mode: MAMode = .auto

    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Query private var profiles: [UserProfile]
    @Query(sort: \NutritionLog.date, order: .reverse) private var logs: [NutritionLog]
    @Query(sort: \SymptomLog.date, order: .reverse) private var symptoms: [SymptomLog]
    @Query(sort: \BodyComposition.date, order: .reverse) private var bodyComp: [BodyComposition]
    @State private var isGenerating = false

    private var profile: UserProfile? { profiles.first }

    private var weekLogs: [NutritionLog] {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        return logs.filter { $0.date > weekAgo }
    }

    private var weekSymptoms: [SymptomLog] {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        return symptoms.filter { $0.date > weekAgo }
    }

    /// Body composition records inside the report window, sorted oldest to
    /// newest so `first` and `last` give us the start and end of the week.
    private var weekBodyComp: [BodyComposition] {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        return bodyComp
            .filter { $0.date > weekAgo }
            .sorted { $0.date < $1.date }
    }

    private var weekStartWeight: Double? { weekBodyComp.first?.weightLbs }
    private var weekEndWeight: Double? { weekBodyComp.last?.weightLbs }

    var body: some View {
        ZStack {
            EditorialBackground(mode: mode)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    HairlineDivider().padding(.vertical, 8)

                    previewSection("NUTRITION") {
                        previewRow("Avg Protein", value: "\(avgProtein)g / \(profile?.proteinTargetGrams ?? 140)g")
                        previewRow("Protein Hit Rate", value: "\(proteinHitRate)%")
                        previewRow("Avg Calories", value: "\(avgCalories)")
                        previewRow("Avg Water", value: String(format: "%.1fL", avgWater))
                    }
                    .padding(.top, 12)

                    previewSection("SYMPTOMS") {
                        previewRow("Avg Nausea", value: String(format: "%.1f / 5", avgNausea))
                        previewRow("Avg Energy", value: String(format: "%.1f / 5", avgEnergy))
                        previewRow("Days Logged", value: "\(weekSymptoms.count)")
                    }
                    .padding(.top, 12)

                    previewSection("MEDICATION") {
                        if let med = profile?.medication {
                            previewRow("Medication", value: med.rawValue)
                        }
                        if let dose = profile?.doseAmount {
                            previewRow("Dose", value: dose)
                        }
                        previewRow("Mode", value: profile?.productMode.rawValue ?? "Everyday")
                    }
                    .padding(.top, 12)

                    if let start = weekStartWeight, let end = weekEndWeight {
                        previewSection("WEIGHT") {
                            previewRow("Start of Week", value: WeightFormat.display(start, system: appState.unitSystem))
                            previewRow("End of Week", value: WeightFormat.display(end, system: appState.unitSystem))
                            let lbsChange = end - start
                            let displayChange = appState.unitSystem == .metric ? lbsChange * 0.45359237 : lbsChange
                            let sign = displayChange >= 0 ? "+" : ""
                            previewRow("Change", value: "\(sign)\(String(format: "%.1f", displayChange)) \(WeightFormat.unit(system: appState.unitSystem))")
                        }
                        .padding(.top, 12)
                    }

                    Button {
                        HapticManager.light()
                        Task { await generateAndShare() }
                    } label: {
                        Text(isGenerating ? "GENERATING..." : "GENERATE & SHARE PDF")
                            .font(Theme.Editorial.Typography.capsBold(11))
                            .tracking(2.0)
                            .foregroundStyle(Color(red: 0.961, green: 0.851, blue: 0.478))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Theme.Editorial.onSurface.opacity(0.08))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Theme.Editorial.onSurface.opacity(0.2), lineWidth: 0.5)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(isGenerating)
                    .padding(.top, 18)

                    Text("PDF includes a medical disclaimer. No personal data is shared with third parties.")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.Editorial.onSurface.opacity(0.6))
                        .lineSpacing(3)
                        .padding(.top, 10)

                    Spacer(minLength: 40)
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
    }

    // MARK: - Preview Components

    @ViewBuilder
    private func previewSection(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(Theme.Editorial.Typography.caps(9, weight: .medium))
                .tracking(2.8)
                .foregroundStyle(Theme.Editorial.onSurfaceMuted)
            content()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.18))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Theme.Editorial.onSurface.opacity(0.18), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func previewRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(Theme.Editorial.onSurface.opacity(0.7))
            Spacer()
            Text(value)
                .font(Theme.Editorial.Typography.caps(10, weight: .semibold))
                .tracking(1.6)
                .foregroundStyle(Theme.Editorial.onSurface)
        }
    }

    private var header: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 56)
            Image(systemName: "doc.text")
                .font(.system(size: 22))
                .foregroundStyle(Theme.Editorial.onSurface)
                .padding(.bottom, 14)
            Text("Provider Report")
                .font(.system(size: 26, weight: .regular, design: .serif))
                .tracking(0.6)
                .foregroundStyle(Theme.Editorial.onSurface)
            Text("WEEKLY SUMMARY · PDF")
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

    // MARK: - Data

    private var avgProtein: Int {
        guard !weekLogs.isEmpty else { return 0 }
        return Int(weekLogs.reduce(0.0) { $0 + $1.proteinGrams } / Double(weekLogs.count))
    }

    private var proteinHitRate: Int {
        guard !weekLogs.isEmpty, let target = profile?.proteinTargetGrams else { return 0 }
        let hits = weekLogs.filter { $0.proteinGrams >= Double(target) * 0.9 }.count
        return (hits * 100) / weekLogs.count
    }

    private var avgCalories: Int {
        guard !weekLogs.isEmpty else { return 0 }
        return Int(weekLogs.reduce(0.0) { $0 + $1.caloriesConsumed } / Double(weekLogs.count))
    }

    private var avgWater: Double {
        guard !weekLogs.isEmpty else { return 0 }
        return weekLogs.reduce(0.0) { $0 + $1.waterLiters } / Double(weekLogs.count)
    }

    private var avgNausea: Double {
        guard !weekSymptoms.isEmpty else { return 0 }
        return Double(weekSymptoms.reduce(0) { $0 + $1.nauseaLevel }) / Double(weekSymptoms.count)
    }

    private var avgEnergy: Double {
        guard !weekSymptoms.isEmpty else { return 0 }
        return Double(weekSymptoms.reduce(0) { $0 + $1.energyLevel }) / Double(weekSymptoms.count)
    }

    // MARK: - Generate

    private func generateAndShare() async {
        isGenerating = true
        HapticManager.medium()
        defer { isGenerating = false }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let endDate = Date.now
        let startDate = Calendar.current.date(byAdding: .day, value: -7, to: endDate) ?? endDate

        let reportData = ProviderReportGenerator.ReportData(
            dateRange: "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))",
            medication: profile?.medication?.rawValue ?? "Not specified",
            dose: profile?.doseAmount ?? "Not specified",
            mode: profile?.productMode.rawValue ?? "Everyday",
            avgProtein: avgProtein,
            proteinTarget: profile?.proteinTargetGrams ?? 140,
            proteinHitRate: proteinHitRate,
            avgCalories: avgCalories,
            avgWater: avgWater,
            avgNausea: avgNausea,
            avgEnergy: avgEnergy,
            daysLogged: weekSymptoms.count,
            weightStart: weekStartWeight,
            weightEnd: weekEndWeight
        )

        // Yield once before the synchronous PDF render so SwiftUI gets a
        // chance to commit the "Generating…" state. Without this the
        // button label flashed too fast to read.
        await Task.yield()

        let pdfData = ProviderReportGenerator.generatePDF(data: reportData)

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("MemoryAisle-Report.pdf")
        try? pdfData.write(to: tempURL)

        presentShareSheet(for: tempURL)
    }

    /// Presents the system share sheet from the active key window. Falls
    /// back gracefully if no window is available rather than crashing.
    private func presentShareSheet(for url: URL) {
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)

        let scenes = UIApplication.shared.connectedScenes
        guard let windowScene = scenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) ?? scenes.first as? UIWindowScene,
              let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }) ?? windowScene.windows.first,
              let rootVC = keyWindow.rootViewController else {
            return
        }

        // Walk to the topmost presented controller so the share sheet
        // attaches to whatever modal is currently on screen.
        var top = rootVC
        while let presented = top.presentedViewController {
            top = presented
        }
        top.present(activityVC, animated: true)
    }
}
