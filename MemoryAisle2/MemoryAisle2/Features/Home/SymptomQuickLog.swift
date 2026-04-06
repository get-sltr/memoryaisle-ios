import SwiftData
import SwiftUI

struct SymptomQuickLog: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.modelContext) private var modelContext
    @State private var hasLoggedToday = false
    @State private var nauseaLevel: Int = 0
    @State private var appetiteLevel: Int = 3
    @State private var energyLevel: Int = 3

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
                Text("How are you feeling?")
                    .font(Typography.bodyMediumBold)
                    .foregroundStyle(Theme.Text.primary)

                symptomSlider("Nausea", value: $nauseaLevel, low: "None", high: "Severe", color: Theme.Semantic.warning(for: scheme))
                symptomSlider("Appetite", value: $appetiteLevel, low: "Low", high: "Normal", color: Theme.Semantic.fiber(for: scheme))
                symptomSlider("Energy", value: $energyLevel, low: "Low", high: "High", color: Theme.Semantic.onTrack(for: scheme))

                VioletButtonCompact("Log symptoms") {
                    saveSymptoms()
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(Theme.Spacing.md)
        }
    }

    private var loggedCard: some View {
        GlassCard {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Theme.Semantic.onTrack(for: scheme))
                    .font(.system(size: 20))

                Text("Symptoms logged for today")
                    .font(Typography.bodySmall)
                    .foregroundStyle(Theme.Text.secondary(for: scheme))

                Spacer()
            }
            .padding(Theme.Spacing.md)
        }
    }

    // MARK: - Slider

    private func symptomSlider(
        _ label: String,
        value: Binding<Int>,
        low: String,
        high: String,
        color: Color
    ) -> some View {
        VStack(spacing: Theme.Spacing.xs) {
            HStack {
                Text(label)
                    .font(Typography.bodySmall)
                    .foregroundStyle(Theme.Text.secondary(for: scheme))
                Spacer()
                Text("\(value.wrappedValue)/5")
                    .font(Typography.monoSmall)
                    .foregroundStyle(color)
            }

            HStack(spacing: Theme.Spacing.xs) {
                Text(low)
                    .font(Typography.caption)
                    .foregroundStyle(Theme.Text.tertiary(for: scheme))
                    .frame(width: 44, alignment: .leading)

                HStack(spacing: Theme.Spacing.xs) {
                    ForEach(0...5, id: \.self) { level in
                        Button {
                            HapticManager.selection()
                            value.wrappedValue = level
                        } label: {
                            Circle()
                                .fill(level <= value.wrappedValue ? color : color.opacity(0.15))
                                .frame(width: 20, height: 20)
                        }
                    }
                }

                Text(high)
                    .font(Typography.caption)
                    .foregroundStyle(Theme.Text.tertiary(for: scheme))
                    .frame(width: 44, alignment: .trailing)
            }
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
        withAnimation(Theme.Motion.spring) {
            hasLoggedToday = true
        }
    }
}
