import SwiftData
import SwiftUI

struct ProgressDashboardView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [UserProfile]
    @Query(sort: \NutritionLog.date, order: .reverse) private var logs: [NutritionLog]
    @Query(sort: \BodyComposition.date, order: .reverse) private var bodyComp: [BodyComposition]
    @Query(sort: \TrainingSession.date, order: .reverse) private var trainingSessions: [TrainingSession]
    @State private var healthKit = HealthKitManager()
    @State private var showGITolerance = false
    @State private var showProviderReport = false

    private var profile: UserProfile? { profiles.first }

    private var todaysLogs: [NutritionLog] {
        logs.filter { Calendar.current.isDateInToday($0.date) }
    }

    /// Aggregated totals for today, summed across every NutritionLog row
    /// dated today. The model stores one row per meal event, so the
    /// dashboard must sum rather than read a single "daily" row.
    private var todayTotals: (protein: Double, water: Double, fiber: Double, calories: Double)? {
        let rows = todaysLogs
        guard !rows.isEmpty else { return nil }
        return (
            protein: rows.reduce(0) { $0 + $1.proteinGrams },
            water: rows.reduce(0) { $0 + $1.waterLiters },
            fiber: rows.reduce(0) { $0 + $1.fiberGrams },
            calories: rows.reduce(0) { $0 + $1.caloriesConsumed }
        )
    }

    private var weekLogs: [NutritionLog] {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        return logs.filter { $0.date > weekAgo }
    }

    private var proteinHitRate: Int {
        guard !weekLogs.isEmpty, let target = profile?.proteinTargetGrams else { return 0 }
        let hits = weekLogs.filter { $0.proteinGrams >= Double(target) * 0.9 }.count
        return (hits * 100) / weekLogs.count
    }

    private var avgProtein: Int {
        guard !weekLogs.isEmpty else { return 0 }
        return Int(weekLogs.reduce(0.0) { $0 + $1.proteinGrams } / Double(weekLogs.count))
    }

    private var avgHydration: Int {
        guard !weekLogs.isEmpty, let target = profile?.waterTargetLiters, target > 0 else { return 0 }
        let avg = weekLogs.reduce(0.0) { $0 + $1.waterLiters } / Double(weekLogs.count)
        return Int((avg / target) * 100)
    }

    /// Unified weight history combining manual BodyComposition records and
    /// HealthKit samples, sorted chronologically. The user's first check-in
    /// shows up here even before they've connected HealthKit, which fixes
    /// the bug where manual check-ins didn't appear in the trend chart.
    private var combinedWeightHistory: [(date: Date, value: Double)] {
        let manual = bodyComp.map { (date: $0.date, value: $0.weightLbs) }
        let merged = manual + healthKit.weightHistory
        return merged.sorted { $0.date < $1.date }
    }

    /// True when the user has at least one source of progress data.
    /// Drives the top-level empty state for a brand-new user who hasn't
    /// logged anything yet.
    private var hasAnyData: Bool {
        !logs.isEmpty
            || !bodyComp.isEmpty
            || !trainingSessions.isEmpty
            || !healthKit.weightHistory.isEmpty
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                // Header
                HStack {
                    CloseButton(action: { dismiss() })
                        .section(.progress)

                    Text("Progress")
                        .font(.system(size: 26, weight: .light, design: .serif))
                        .foregroundStyle(Theme.Text.primary)
                        .tracking(0.3)
                        .padding(.leading, 8)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                // Top-level empty state for a brand-new user with no data
                if !hasAnyData {
                    topLevelEmptyState
                }

                // Weekly stats — only render when the user has actually
                // logged at least one meal this week. Otherwise the cards
                // would show 0% / 0g / 0% which reads as fake.
                if !weekLogs.isEmpty {
                    HStack(spacing: 10) {
                        statCard("Protein\nHit Rate", value: "\(proteinHitRate)%", color: Color.violet)
                        statCard("Avg Daily\nProtein", value: "\(avgProtein)g", color: Color.violet)
                        statCard("Hydration", value: "\(avgHydration)%", color: Theme.Semantic.water(for: scheme))
                    }
                    .padding(.horizontal, 20)
                }

                // Today's macros — only render when the user has logged
                // something today. Empty zero rows would look like placecards.
                if let todayTotals {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("TODAY")
                            .font(Typography.label)
                            .foregroundStyle(Theme.Text.tertiary(for: scheme))
                            .tracking(1.2)

                        macroRow("Protein", current: todayTotals.protein, target: Double(profile?.proteinTargetGrams ?? 140), unit: "g", color: Color.violet)
                        macroRow("Water", current: todayTotals.water, target: profile?.waterTargetLiters ?? 2.5, unit: "L", color: Theme.Semantic.water(for: scheme))
                        macroRow("Fiber", current: todayTotals.fiber, target: Double(profile?.fiberTargetGrams ?? 25), unit: "g", color: Theme.Semantic.fiber(for: scheme))
                        macroRow("Calories", current: todayTotals.calories, target: Double(profile?.calorieTarget ?? 1800), unit: "", color: Theme.Text.secondary(for: scheme))
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

                // 7-day chart
                if !weekLogs.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("7-DAY PROTEIN")
                            .font(Typography.label)
                            .foregroundStyle(Theme.Text.tertiary(for: scheme))
                            .tracking(1.2)

                        HStack(alignment: .bottom, spacing: 6) {
                            ForEach(Array(weekLogs.suffix(7).reversed().enumerated()), id: \.offset) { _, log in
                                let target = Double(profile?.proteinTargetGrams ?? 140)
                                let pct = target > 0 ? min(log.proteinGrams / target, 1.0) : 0

                                VStack(spacing: 4) {
                                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                                        .fill(
                                            pct >= 0.9
                                                ? Theme.Semantic.onTrack(for: scheme)
                                                : pct >= 0.7
                                                    ? Theme.Semantic.behind(for: scheme)
                                                    : Theme.Semantic.warning(for: scheme)
                                        )
                                        .frame(height: max(6, 70 * pct))

                                    Text(dayLabel(log.date))
                                        .font(.system(size: 9))
                                        .foregroundStyle(Theme.Text.tertiary(for: scheme))
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .frame(height: 90, alignment: .bottom)
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

                // Weight trend chart — combines manual BodyComposition
                // records with HealthKit samples so manual check-ins show
                // up in the chart even before HealthKit is connected.
                WeightTrendChart(data: combinedWeightHistory)
                    .padding(.horizontal, 20)

                // Body composition
                if let latest = bodyComp.first {
                    bodyCompSection(latest)
                }

                // Training this week
                if !trainingSessions.isEmpty {
                    trainingSection
                }

                // Action buttons
                HStack(spacing: 10) {
                    actionButton("GI Tolerance", icon: "leaf.fill") {
                        showGITolerance = true
                    }
                    actionButton("Provider Report", icon: "doc.text.fill") {
                        showProviderReport = true
                    }
                }
                .padding(.horizontal, 20)

                Spacer(minLength: 80)
            }
            .readableContentWidth()
        }
        .section(.progress)
        .themeBackground()
        .navigationBarHidden(true)
        .task {
            await healthKit.fetchLatestWeight()
            await healthKit.fetchWeightHistory()
        }
        .sheet(isPresented: $showGITolerance) { GIToleranceView() }
        .sheet(isPresented: $showProviderReport) {
            ProviderReportView().biometricProtected()
        }
    }

    // MARK: - Components

    private func statCard(_ label: String, value: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Text(value)
                .font(Typography.displaySmallMono)
                .fontWeight(.medium)
                .foregroundStyle(Theme.Text.primary)

            Text(label)
                .font(Typography.label)
                .foregroundStyle(Theme.Text.tertiary(for: scheme))
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(color.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(color.opacity(0.12), lineWidth: 0.5)
        )
    }

    private func macroRow(_ label: String, current: Double, target: Double, unit: String, color: Color) -> some View {
        VStack(spacing: 6) {
            HStack {
                Text(label)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.Text.secondary(for: scheme))
                Spacer()
                Text("\(Int(current))/\(Int(target))\(unit)")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(color)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(color.opacity(0.1))

                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(color)
                        .frame(width: geo.size.width * (target > 0 ? min(current / target, 1) : 0))
                }
            }
            .frame(height: 4)
        }
    }

    private func dayLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "E"
        return String(f.string(from: date).prefix(1))
    }

    private func bodyCompSection(_ latest: BodyComposition) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("BODY COMPOSITION")
                .font(Typography.label)
                .foregroundStyle(Theme.Text.tertiary(for: scheme))
                .tracking(1.2)

            HStack(spacing: 10) {
                statCard(
                    "Weight",
                    value: "\(Int(latest.weightLbs)) lbs",
                    color: Theme.Text.secondary(for: scheme)
                )
                statCard(
                    "Lean Mass",
                    value: "\(Int(latest.computedLeanMass)) lbs",
                    color: Color.violet
                )
                if let bf = latest.bodyFatPercent {
                    statCard(
                        "Body Fat",
                        value: String(format: "%.1f%%", bf),
                        color: Theme.Semantic.fiber(for: scheme)
                    )
                }
            }

            if bodyComp.count >= 2 {
                let first = bodyComp.last
                let change = latest.weightLbs - (first?.weightLbs ?? latest.weightLbs)
                let leanChange = latest.computedLeanMass - (first?.computedLeanMass ?? latest.computedLeanMass)
                HStack(spacing: 16) {
                    trendLabel("Weight", change: change, unit: "lbs")
                    trendLabel("Lean", change: leanChange, unit: "lbs")
                }
            }
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

    private func trendLabel(_ label: String, change: Double, unit: String) -> some View {
        let isPositive = change >= 0
        let color: Color = label == "Lean"
            ? (isPositive ? Theme.Semantic.onTrack(for: scheme) : Theme.Semantic.warning(for: scheme))
            : (isPositive ? Theme.Semantic.warning(for: scheme) : Theme.Semantic.onTrack(for: scheme))

        return HStack(spacing: 4) {
            Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 10))
            Text(String(format: "%+.1f %@", change, unit))
                .font(.system(size: 11, design: .monospaced))
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Theme.Text.secondary(for: scheme))
        }
        .foregroundStyle(color)
    }

    private var trainingSection: some View {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        let weekSessions = trainingSessions.filter { $0.date >= weekAgo }
        let strengthCount = weekSessions.filter(\.isStrengthTraining).count
        let totalMinutes = weekSessions.reduce(0) { $0 + $1.durationMinutes }

        return VStack(alignment: .leading, spacing: 12) {
            Text("TRAINING THIS WEEK")
                .font(Typography.label)
                .foregroundStyle(Theme.Text.tertiary(for: scheme))
                .tracking(1.2)

            HStack(spacing: 10) {
                statCard("Sessions", value: "\(weekSessions.count)", color: Color.violet)
                statCard("Strength", value: "\(strengthCount)", color: Theme.Semantic.fiber(for: scheme))
                statCard("Minutes", value: "\(totalMinutes)", color: Theme.Semantic.water(for: scheme))
            }
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

    private var topLevelEmptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 28))
                .foregroundStyle(Color.violet.opacity(0.4))
            Text("Your progress will live here.")
                .font(.system(size: 18, weight: .regular, design: .serif))
                .foregroundStyle(Theme.Text.primary)
                .multilineTextAlignment(.center)
            Text("Log a meal from the dashboard or do a weekly check-in to start tracking your week.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.Text.secondary(for: scheme))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 20)
    }

    private func actionButton(_ label: String, icon: String, action: @escaping () -> Void) -> some View {
        Button {
            HapticManager.light()
            action()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.violet)
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.Text.secondary(for: scheme))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Theme.Surface.glass(for: scheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Theme.Border.glass(for: scheme), lineWidth: Theme.glassBorderWidth)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
