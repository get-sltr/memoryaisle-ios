import SwiftData
import SwiftUI

struct ProgressDashboardView: View {
    @Environment(\.colorScheme) private var scheme
    @Query private var profiles: [UserProfile]
    @Query(sort: \NutritionLog.date, order: .reverse) private var logs: [NutritionLog]

    private var profile: UserProfile? { profiles.first }
    private var todayLog: NutritionLog? {
        logs.first { Calendar.current.isDateInToday($0.date) }
    }

    private var weekLogs: [NutritionLog] {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        return logs.filter { $0.date > weekAgo }
    }

    private var proteinHitRate: Int {
        guard !weekLogs.isEmpty, let target = profile?.proteinTargetGrams else { return 0 }
        let hits = weekLogs.filter { $0.proteinGrams >= Double(target) * 0.9 }.count
        return weekLogs.count > 0 ? (hits * 100) / weekLogs.count : 0
    }

    private var avgProtein: Int {
        guard !weekLogs.isEmpty else { return 0 }
        let total = weekLogs.reduce(0.0) { $0 + $1.proteinGrams }
        return Int(total / Double(weekLogs.count))
    }

    private var avgHydration: Int {
        guard !weekLogs.isEmpty, let target = profile?.waterTargetLiters, target > 0 else { return 0 }
        let avg = weekLogs.reduce(0.0) { $0 + $1.waterLiters } / Double(weekLogs.count)
        return Int((avg / target) * 100)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.md) {
                HStack {
                    Text("Progress")
                        .font(Typography.displaySmall)
                        .foregroundStyle(Theme.Text.primary)
                    Spacer()
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
                            statItem(
                                "Protein Hit Rate",
                                value: "\(proteinHitRate)%",
                                trend: proteinHitRate >= 70 ? .onTrack : .behind
                            )
                            statItem(
                                "Avg Daily Protein",
                                value: "\(avgProtein)g",
                                trend: avgProtein >= (profile?.proteinTargetGrams ?? 100) ? .onTrack : .behind
                            )
                            statItem(
                                "Hydration",
                                value: "\(avgHydration)%",
                                trend: avgHydration >= 70 ? .onTrack : .behind
                            )
                        }
                    }
                    .padding(Theme.Spacing.md)
                }
                .padding(.horizontal, Theme.Spacing.md)

                // Today's progress
                GlassCard {
                    VStack(spacing: Theme.Spacing.md) {
                        HStack {
                            Text("Today")
                                .font(Typography.bodyMediumBold)
                                .foregroundStyle(Theme.Text.primary)
                            Spacer()
                        }

                        LabeledProgressBar(
                            title: "Protein",
                            current: todayLog?.proteinGrams ?? 0,
                            target: Double(profile?.proteinTargetGrams ?? 140),
                            unit: "g",
                            category: .protein
                        )
                        LabeledProgressBar(
                            title: "Water",
                            current: todayLog?.waterLiters ?? 0,
                            target: profile?.waterTargetLiters ?? 2.5,
                            unit: "L",
                            category: .water
                        )
                        LabeledProgressBar(
                            title: "Fiber",
                            current: todayLog?.fiberGrams ?? 0,
                            target: Double(profile?.fiberTargetGrams ?? 25),
                            unit: "g",
                            category: .fiber
                        )
                        LabeledProgressBar(
                            title: "Calories",
                            current: todayLog?.caloriesConsumed ?? 0,
                            target: Double(profile?.calorieTarget ?? 1800),
                            unit: "",
                            category: .calories
                        )
                    }
                    .padding(Theme.Spacing.md)
                }
                .padding(.horizontal, Theme.Spacing.md)

                // Week history
                if !weekLogs.isEmpty {
                    GlassCard {
                        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                            Text("7-Day Protein")
                                .font(Typography.bodyMediumBold)
                                .foregroundStyle(Theme.Text.primary)

                            HStack(alignment: .bottom, spacing: Theme.Spacing.xs) {
                                ForEach(Array(weekLogs.suffix(7).reversed().enumerated()), id: \.offset) { _, log in
                                    let target = Double(profile?.proteinTargetGrams ?? 140)
                                    let pct = target > 0 ? min(log.proteinGrams / target, 1.0) : 0

                                    VStack(spacing: Theme.Spacing.xs) {
                                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                                            .fill(
                                                pct >= 0.9
                                                    ? Theme.Semantic.onTrack(for: scheme)
                                                    : pct >= 0.7
                                                        ? Theme.Semantic.behind(for: scheme)
                                                        : Theme.Semantic.warning(for: scheme)
                                            )
                                            .frame(height: max(8, 80 * pct))

                                        Text(dayLabel(log.date))
                                            .font(Typography.caption)
                                            .foregroundStyle(Theme.Text.tertiary(for: scheme))
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                            }
                            .frame(height: 100, alignment: .bottom)
                        }
                        .padding(Theme.Spacing.md)
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                }

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

    private func dayLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return String(formatter.string(from: date).prefix(1))
    }
}
