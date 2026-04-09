import SwiftData
import SwiftUI

struct GIToleranceView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GIToleranceRecord.date, order: .reverse) private var records: [GIToleranceRecord]
    @State private var showLogFood = false
    @State private var logFoodName = ""
    @State private var logNausea = false
    @State private var logBloating = false
    @State private var logSeverity = 1

    private var risks: [GIToleranceEngine.FoodRisk] {
        GIToleranceEngine.analyzeRisks(records: records)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.violet.opacity(0.6))
                }
                Spacer()
                Text("GI Tolerance")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Theme.Text.primary)
                Spacer()
                Button { showLogFood = true } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.violet)
                        
                        .background(Circle().fill(Color.violet.opacity(0.1)))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            if risks.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(Theme.Text.tertiary(for: scheme))
                    Text("No food reactions logged yet")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.Text.tertiary(for: scheme))
                    Text("Log foods that cause symptoms.\nMira will learn to avoid them.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.Text.tertiary(for: scheme))
                        .multilineTextAlignment(.center)
                    Spacer()
                }
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 8) {
                        ForEach(risks) { risk in
                            riskRow(risk)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
            }
        }
        .themeBackground()
        .alert("Log Food Reaction", isPresented: $showLogFood) {
            TextField("Food name", text: $logFoodName)
            Button("Log") { saveReaction() }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func riskRow(_ risk: GIToleranceEngine.FoodRisk) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(risk.foodName)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.Text.primary)
                Text("\(risk.primarySymptom) · \(risk.triggerCount)/\(risk.totalExposures) times")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.Text.tertiary(for: scheme))
            }

            Spacer()

            Text(risk.riskLevel.rawValue)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(hex: UInt(risk.riskLevel.color, radix: 16) ?? 0xFFFFFF))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule().fill(Color(hex: UInt(risk.riskLevel.color, radix: 16) ?? 0xFFFFFF).opacity(0.12))
                )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.Surface.glass(for: scheme))
        )
    }

    private func saveReaction() {
        guard !logFoodName.isEmpty else { return }
        let record = GIToleranceRecord(
            foodName: logFoodName,
            triggeredNausea: true,
            severity: logSeverity
        )
        modelContext.insert(record)
        logFoodName = ""
        HapticManager.success()
    }
}
