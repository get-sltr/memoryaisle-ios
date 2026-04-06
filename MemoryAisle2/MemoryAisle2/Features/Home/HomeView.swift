import SwiftUI

struct HomeView: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.md) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text("Good morning")
                            .font(Typography.bodyMedium)
                            .foregroundStyle(Theme.Text.secondary(for: scheme))
                        Text("Your Daily Plan")
                            .font(Typography.displaySmall)
                            .foregroundStyle(Theme.Text.primary)
                    }

                    Spacer()

                    MiraWaveform(state: .idle, size: .compact)
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.top, Theme.Spacing.sm)

                // Protein Hero Card
                GlassCardStrong {
                    VStack(spacing: Theme.Spacing.md) {
                        HStack {
                            Text("Protein")
                                .font(Typography.bodyMediumBold)
                                .foregroundStyle(Theme.Semantic.protein(for: scheme))
                            Spacer()
                            PillBadge(.behind, label: "22g behind")
                        }

                        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.xs) {
                            Text("98")
                                .font(Typography.monoLarge)
                                .foregroundStyle(Theme.Text.primary)
                            Text("/ 140g")
                                .font(Typography.monoMedium)
                                .foregroundStyle(Theme.Text.secondary(for: scheme))
                        }

                        ProgressBar(progress: 0.7, category: .protein, height: 8)
                    }
                    .padding(Theme.Spacing.md)
                }
                .padding(.horizontal, Theme.Spacing.md)

                // Macro Tiles
                HStack(spacing: Theme.Spacing.sm) {
                    macroTile("Water", value: "1.2", unit: "L", target: "2.5L", category: .water, progress: 0.48)
                    macroTile("Fiber", value: "12", unit: "g", target: "25g", category: .fiber, progress: 0.48)
                    macroTile("Cal", value: "1,180", unit: "", target: "1,800", category: .calories, progress: 0.66)
                }
                .padding(.horizontal, Theme.Spacing.md)

                // Mira Suggestion
                InteractiveGlassCard(action: {}) {
                    HStack(spacing: Theme.Spacing.md) {
                        MiraWaveform(state: .speaking, size: .inline)

                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Text("Mira's suggestion")
                                .font(Typography.caption)
                                .foregroundStyle(Theme.Text.tertiary(for: scheme))
                            Text("You're 22g behind on protein. Greek yogurt + hemp seeds closes the gap in one snack.")
                                .font(Typography.bodyMedium)
                                .foregroundStyle(Theme.Text.primary)
                        }
                    }
                    .padding(Theme.Spacing.md)
                }
                .padding(.horizontal, Theme.Spacing.md)

                // Bottom spacer for tab bar
                Spacer(minLength: 80)
            }
        }
        .themeBackground()
        .navigationBarHidden(true)
    }

    // MARK: - Macro Tile

    private func macroTile(
        _ title: String,
        value: String,
        unit: String,
        target: String,
        category: ProgressCategory,
        progress: Double
    ) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text(title)
                    .font(Typography.caption)
                    .foregroundStyle(Theme.Text.tertiary(for: scheme))

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(value)
                        .font(Typography.monoMedium)
                        .foregroundStyle(Theme.Text.primary)
                    Text(unit)
                        .font(Typography.caption)
                        .foregroundStyle(Theme.Text.secondary(for: scheme))
                }

                ProgressBar(progress: progress, category: category, height: 4)

                Text(target)
                    .font(Typography.caption)
                    .foregroundStyle(Theme.Text.tertiary(for: scheme))
            }
            .padding(Theme.Spacing.sm + 2)
        }
    }
}
