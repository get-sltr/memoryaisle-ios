import SwiftUI

struct MedicationCycleBar: View {
    @Environment(\.colorScheme) private var scheme

    let medicationName: String
    let doseLabel: String
    let currentDay: Int
    let totalDays: Int

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("\(medicationName) \(doseLabel)".uppercased())
                    .font(Typography.micro)
                    .letterSpaced(0.8)
                    .foregroundStyle(Theme.Text.tertiary(for: scheme))

                Text("Day \(currentDay) of \(totalDays)")
                    .font(Typography.bodySmallBold)
                    .foregroundStyle(Theme.Text.primary)

                segmentRow
            }
            .padding(.vertical, 14)
            .padding(.horizontal, Theme.Spacing.cardPad)
        }
    }

    private var segmentRow: some View {
        HStack(spacing: 2) {
            ForEach(1...totalDays, id: \.self) { day in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(
                        day <= currentDay
                            ? Theme.Semantic.streakActive
                            : Theme.Accent.subtle(for: scheme)
                    )
                    .frame(width: 16, height: 3)
            }
        }
    }
}
