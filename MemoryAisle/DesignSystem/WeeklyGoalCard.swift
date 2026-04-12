import SwiftUI

struct WeeklyGoalCard: View {
    @Environment(\.colorScheme) private var scheme

    let goalLabel: String
    let isOnTrack: Bool

    var body: some View {
        GlassCard {
            HStack {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("WEEKLY GOAL")
                        .font(Typography.micro)
                        .letterSpaced(0.8)
                        .foregroundStyle(Theme.Text.tertiary(for: scheme))

                    Text(goalLabel)
                        .font(Typography.bodySmallBold)
                        .foregroundStyle(Theme.Text.primary)
                }

                Spacer()

                HStack(spacing: Theme.Spacing.xs) {
                    Circle()
                        .fill(
                            isOnTrack
                                ? Theme.Semantic.onTrack(for: scheme)
                                : Theme.Semantic.behind(for: scheme)
                        )
                        .frame(width: 6, height: 6)

                    Text(isOnTrack ? "On track" : "Behind")
                        .font(Typography.bodySmall)
                        .foregroundStyle(
                            isOnTrack
                                ? Theme.Semantic.onTrack(for: scheme)
                                : Theme.Semantic.behind(for: scheme)
                        )
                }
            }
            .padding(.vertical, 14)
            .padding(.horizontal, Theme.Spacing.cardPad)
        }
    }
}
