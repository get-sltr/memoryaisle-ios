import SwiftUI

struct ProgressDashboardView: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.md) {
                // Header
                HStack {
                    Text("Progress")
                        .font(Typography.displaySmall)
                        .foregroundStyle(Theme.Text.primary)
                    Spacer()
                    GhostButtonCompact("Export", icon: "square.and.arrow.up") {}
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.top, Theme.Spacing.sm)

                // Weekly summary
                GlassCardStrong {
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        Text("This Week")
                            .font(Typography.bodyMediumBold)
                            .foregroundStyle(Theme.Text.primary)

                        HStack(spacing: Theme.Spacing.lg) {
                            statItem("Protein Hit Rate", value: "71%", trend: .onTrack)
                            statItem("Avg Daily Protein", value: "118g", trend: .behind)
                            statItem("Hydration", value: "85%", trend: .onTrack)
                        }
                    }
                    .padding(Theme.Spacing.md)
                }
                .padding(.horizontal, Theme.Spacing.md)

                // Daily progress bars
                GlassCard {
                    VStack(spacing: Theme.Spacing.md) {
                        LabeledProgressBar(
                            title: "Protein",
                            current: 98,
                            target: 140,
                            unit: "g",
                            category: .protein
                        )
                        LabeledProgressBar(
                            title: "Water",
                            current: 1.2,
                            target: 2.5,
                            unit: "L",
                            category: .water
                        )
                        LabeledProgressBar(
                            title: "Fiber",
                            current: 12,
                            target: 25,
                            unit: "g",
                            category: .fiber
                        )
                        LabeledProgressBar(
                            title: "Calories",
                            current: 1180,
                            target: 1800,
                            unit: "",
                            category: .calories
                        )
                    }
                    .padding(Theme.Spacing.md)
                }
                .padding(.horizontal, Theme.Spacing.md)

                // Weight trend placeholder
                GlassCard {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("Weight Trend")
                            .font(Typography.bodyMediumBold)
                            .foregroundStyle(Theme.Text.primary)

                        Text("Connect HealthKit to see your trend")
                            .font(Typography.bodySmall)
                            .foregroundStyle(Theme.Text.secondary(for: scheme))

                        VioletButton("Connect HealthKit", icon: "heart.fill") {}
                            .padding(.top, Theme.Spacing.xs)
                    }
                    .padding(Theme.Spacing.md)
                }
                .padding(.horizontal, Theme.Spacing.md)

                Spacer(minLength: 80)
            }
        }
        .themeBackground()
        .navigationBarHidden(true)
    }

    private func statItem(_ label: String, value: String, trend: PillStatus) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(value)
                .font(Typography.monoMediumBold)
                .foregroundStyle(Theme.Text.primary)
            Text(label)
                .font(Typography.caption)
                .foregroundStyle(Theme.Text.tertiary(for: scheme))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
