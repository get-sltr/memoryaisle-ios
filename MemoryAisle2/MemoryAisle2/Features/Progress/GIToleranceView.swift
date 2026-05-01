import SwiftData
import SwiftUI

struct GIToleranceView: View {
    var mode: MAMode = .auto

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
        ZStack {
            EditorialBackground(mode: mode)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    HairlineDivider().padding(.vertical, 8)

                    if risks.isEmpty {
                        emptyState
                    } else {
                        VStack(spacing: 10) {
                            ForEach(risks) { risk in
                                riskRow(risk)
                            }
                        }
                        .padding(.top, 8)
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
        .alert("Log Food Reaction", isPresented: $showLogFood) {
            TextField("Food name", text: $logFoodName)
            Button("Log") { saveReaction() }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var header: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 56)
            Image(systemName: "leaf")
                .font(.system(size: 22))
                .foregroundStyle(Theme.Editorial.onSurface)
                .padding(.bottom, 14)
            Text("GI Tolerance")
                .font(.system(size: 26, weight: .regular, design: .serif))
                .tracking(0.6)
                .foregroundStyle(Theme.Editorial.onSurface)
            Text("FOODS · SYMPTOMS · RISK")
                .font(Theme.Editorial.Typography.caps(9, weight: .medium))
                .tracking(2.8)
                .foregroundStyle(Theme.Editorial.onSurfaceMuted)
                .padding(.top, 8)
                .padding(.bottom, 18)

            Button {
                HapticManager.light()
                showLogFood = true
            } label: {
                Text("LOG REACTION")
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
            .padding(.top, 8)
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

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("No food reactions logged yet.")
                .font(.system(size: 17, weight: .light, design: .serif))
                .italic()
                .foregroundStyle(Theme.Editorial.onSurface)
            Text("LOG FOODS THAT CAUSE SYMPTOMS. MIRA WILL LEARN TO AVOID THEM.")
                .font(Theme.Editorial.Typography.caps(9, weight: .medium))
                .tracking(2.2)
                .foregroundStyle(Theme.Editorial.onSurface.opacity(0.5))
                .lineSpacing(2)
        }
        .padding(.vertical, 24)
    }

    private func riskRow(_ risk: GIToleranceEngine.FoodRisk) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(risk.foodName)
                    .font(.system(size: 16, weight: .regular, design: .serif))
                    .foregroundStyle(Theme.Editorial.onSurface)
                Text("\(risk.primarySymptom) · \(risk.triggerCount)/\(risk.totalExposures) times")
                    .font(Theme.Editorial.Typography.caps(9, weight: .medium))
                    .tracking(1.6)
                    .foregroundStyle(Theme.Editorial.onSurface.opacity(0.55))
            }

            Spacer()

            Text(risk.riskLevel.rawValue)
                .font(Theme.Editorial.Typography.caps(9, weight: .semibold))
                .tracking(2.0)
                .foregroundStyle(Theme.Editorial.onSurface.opacity(0.85))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule().fill(Theme.Editorial.onSurface.opacity(0.08))
                )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.18))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Theme.Editorial.onSurface.opacity(0.18), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
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
