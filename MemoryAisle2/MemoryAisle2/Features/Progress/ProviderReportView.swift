import SwiftData
import SwiftUI

struct ProviderReportView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [UserProfile]
    @Query(sort: \NutritionLog.date, order: .reverse) private var logs: [NutritionLog]
    @Query(sort: \SymptomLog.date, order: .reverse) private var symptoms: [SymptomLog]
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

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                CloseButton(action: { dismiss() })
                    .section(.progress)
                Spacer()
                Text("Provider Report")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Theme.Text.primary)
                Spacer()
                Color.clear
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Preview header
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(Color.violet.opacity(0.5))

                        Text("Weekly Report")
                            .font(.system(size: 24, weight: .light, design: .serif))
                            .foregroundStyle(Theme.Text.primary)
                            .tracking(0.3)

                        Text("Share a summary of your week\nwith your healthcare provider.")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.Text.tertiary(for: scheme))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)

                    // Preview data
                    previewSection("Nutrition") {
                        previewRow("Avg Protein", value: "\(avgProtein)g / \(profile?.proteinTargetGrams ?? 140)g")
                        previewRow("Protein Hit Rate", value: "\(proteinHitRate)%")
                        previewRow("Avg Calories", value: "\(avgCalories)")
                        previewRow("Avg Water", value: String(format: "%.1fL", avgWater))
                    }

                    previewSection("Symptoms") {
                        previewRow("Avg Nausea", value: String(format: "%.1f / 5", avgNausea))
                        previewRow("Avg Energy", value: String(format: "%.1f / 5", avgEnergy))
                        previewRow("Days Logged", value: "\(weekSymptoms.count)")
                    }

                    previewSection("Medication") {
                        if let med = profile?.medication {
                            previewRow("Medication", value: med.rawValue)
                        }
                        if let dose = profile?.doseAmount {
                            previewRow("Dose", value: dose)
                        }
                        previewRow("Mode", value: profile?.productMode.rawValue ?? "Everyday")
                    }

                    GlowButton(isGenerating ? "Generating..." : "Generate & Share PDF") {
                        generateAndShare()
                    }
                    .padding(.horizontal, 32)

                    Text("PDF includes a medical disclaimer.\nNo personal data is shared with third parties.")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.Text.tertiary(for: scheme))
                        .multilineTextAlignment(.center)

                    Spacer(minLength: 40)
                }
            }
        }
        .themeBackground()
    }

    // MARK: - Preview Components

    @ViewBuilder
    private func previewSection(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Theme.Text.tertiary(for: scheme))
                .tracking(1.2)
            content()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.Surface.glass(for: scheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Theme.Border.glass(for: scheme), lineWidth: Theme.glassBorderWidth)
        )
        .padding(.horizontal, 20)
    }

    private func previewRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(Theme.Text.secondary(for: scheme))
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(Theme.Text.primary)
        }
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

    private func generateAndShare() {
        isGenerating = true
        HapticManager.medium()

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let endDate = Date.now
        let startDate = Calendar.current.date(byAdding: .day, value: -7, to: endDate) ?? endDate

        let reportData = ProviderReportGenerator.ReportData(
            dateRange: "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))",
            medication: profile?.medication?.rawValue ?? "Not specified",
            dose: profile?.doseAmount ?? "Not specified",
            mode: profile?.productMode.rawValue ?? "Everyday GLP-1",
            avgProtein: avgProtein,
            proteinTarget: profile?.proteinTargetGrams ?? 140,
            proteinHitRate: proteinHitRate,
            avgCalories: avgCalories,
            avgWater: avgWater,
            avgNausea: avgNausea,
            avgEnergy: avgEnergy,
            weightStart: nil,
            weightEnd: nil
        )

        let pdfData = ProviderReportGenerator.generatePDF(data: reportData)

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("MemoryAisle-Report.pdf")
        try? pdfData.write(to: tempURL)

        let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }

        isGenerating = false
    }
}
