import SwiftData
import SwiftUI

struct SymptomQuickLog: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SymptomLog.date, order: .reverse) private var symptomLogs: [SymptomLog]
    @State private var nauseaLevel: Int = 0
    @State private var appetiteLevel: Int = 3
    @State private var energyLevel: Int = 3

    // Source of truth for today's-already-logged state is the SwiftData
    // query, not local @State. Without this, the log UI reappears every
    // time Home remounts (app relaunch, tab swap) even though the user
    // already logged, which reads as broken.
    private var hasLoggedToday: Bool {
        symptomLogs.contains { Calendar.current.isDateInToday($0.date) }
    }

    var body: some View {
        if hasLoggedToday {
            loggedCard
        } else {
            logCard
        }
    }

    // MARK: - Log Card

    private var logCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack {
                    Text("How are you feeling?")
                        .font(Typography.bodySmallBold)
                        .foregroundStyle(Theme.Text.primary)
                    Spacer()
                    VioletButtonCompact("Log") {
                        saveSymptoms()
                    }
                }

                symptomRow("Nausea", value: $nauseaLevel, low: "None", high: "Severe", color: Theme.Semantic.warning(for: scheme))
                symptomRow("Appetite", value: $appetiteLevel, low: "Low", high: "Normal", color: Theme.Semantic.fiber(for: scheme))
                symptomRow("Energy", value: $energyLevel, low: "Low", high: "High", color: Theme.Semantic.onTrack(for: scheme))
            }
            .padding(Theme.Spacing.md)
        }
    }

    private var loggedCard: some View {
        GlassCard {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Theme.Semantic.onTrack(for: scheme))
                    .font(.system(size: 16))

                Text("Symptoms logged")
                    .font(Typography.bodySmall)
                    .foregroundStyle(Theme.Text.secondary(for: scheme))

                Spacer()
            }
            .padding(Theme.Spacing.sm + 2)
        }
    }

    // MARK: - Symptom Row

    private func symptomRow(
        _ label: String,
        value: Binding<Int>,
        low: String,
        high: String,
        color: Color
    ) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Text(label)
                .font(Typography.caption)
                .foregroundStyle(Theme.Text.secondary(for: scheme))
                .frame(width: 52, alignment: .leading)

            // Segmented bar
            HStack(spacing: 3) {
                ForEach(0...5, id: \.self) { level in
                    Button {
                        HapticManager.selection()
                        withAnimation(Theme.Motion.press) {
                            value.wrappedValue = level
                        }
                    } label: {
                        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                            .fill(
                                level <= value.wrappedValue
                                    ? color
                                    : color.opacity(0.1)
                            )
                            .frame(height: 6)
                    }
                }
            }

            Text("\(value.wrappedValue)")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(color)
                .frame(width: 16, alignment: .trailing)
        }
    }

    // MARK: - Save

    private func saveSymptoms() {
        let log = SymptomLog(
            nauseaLevel: nauseaLevel,
            appetiteLevel: appetiteLevel,
            energyLevel: energyLevel
        )
        modelContext.insert(log)
        HapticManager.success()
    }
}
