import SwiftData
import SwiftUI

struct ProgressDashboardView: View {
    @Environment(\.colorScheme) private var scheme
    @Query private var profiles: [UserProfile]
    @Query(sort: \NutritionLog.date, order: .reverse) private var logs: [NutritionLog]
    @State private var healthKit = HealthKitManager()
    @State private var showGITolerance = false
    @State private var showProviderReport = false

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

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                // Header
                HStack {
                    Text("Progress")
                        .font(.system(size: 26, weight: .light, design: .serif))
                        .foregroundStyle(.white)
                        .tracking(0.3)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                // Weekly stats
                HStack(spacing: 10) {
                    statCard("Protein\nHit Rate", value: "\(proteinHitRate)%", color: Color.violet)
                    statCard("Avg Daily\nProtein", value: "\(avgProtein)g", color: Color.violet)
                    statCard("Hydration", value: "\(avgHydration)%", color: Color(hex: 0x38BDF8))
                }
                .padding(.horizontal, 20)

                // Today's macros
                VStack(alignment: .leading, spacing: 14) {
                    Text("TODAY")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.25))
                        .tracking(1.2)

                    macroRow("Protein", current: todayLog?.proteinGrams ?? 0, target: Double(profile?.proteinTargetGrams ?? 140), unit: "g", color: Color.violet)
                    macroRow("Water", current: todayLog?.waterLiters ?? 0, target: profile?.waterTargetLiters ?? 2.5, unit: "L", color: Color(hex: 0x38BDF8))
                    macroRow("Fiber", current: todayLog?.fiberGrams ?? 0, target: Double(profile?.fiberTargetGrams ?? 25), unit: "g", color: Color(hex: 0xFBBF24))
                    macroRow("Calories", current: todayLog?.caloriesConsumed ?? 0, target: Double(profile?.calorieTarget ?? 1800), unit: "", color: .white.opacity(0.4))
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.white.opacity(0.03))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(.white.opacity(0.06), lineWidth: 0.5)
                )
                .padding(.horizontal, 20)

                // 7-day chart
                if !weekLogs.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("7-DAY PROTEIN")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.25))
                            .tracking(1.2)

                        HStack(alignment: .bottom, spacing: 6) {
                            ForEach(Array(weekLogs.suffix(7).reversed().enumerated()), id: \.offset) { _, log in
                                let target = Double(profile?.proteinTargetGrams ?? 140)
                                let pct = target > 0 ? min(log.proteinGrams / target, 1.0) : 0

                                VStack(spacing: 4) {
                                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                                        .fill(
                                            pct >= 0.9
                                                ? Color(hex: 0x34D399)
                                                : pct >= 0.7
                                                    ? Color(hex: 0xFBBF24)
                                                    : Color(hex: 0xF87171)
                                        )
                                        .frame(height: max(6, 70 * pct))

                                    Text(dayLabel(log.date))
                                        .font(.system(size: 9))
                                        .foregroundStyle(.white.opacity(0.2))
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .frame(height: 90, alignment: .bottom)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(.white.opacity(0.03))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(.white.opacity(0.06), lineWidth: 0.5)
                    )
                    .padding(.horizontal, 20)
                }

                // Weight trend chart
                WeightTrendChart(data: healthKit.weightHistory)
                    .padding(.horizontal, 20)

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

                // HealthKit connect if not authorized
                if !healthKit.isAuthorized {
                    GlowButton("Connect HealthKit") {
                        Task { await healthKit.requestAuthorization() }
                    }
                    .padding(.horizontal, 40)
                }

                Spacer(minLength: 80)
            }
        }
        .themeBackground()
        .navigationBarHidden(true)
        .sheet(isPresented: $showGITolerance) { GIToleranceView() }
        .sheet(isPresented: $showProviderReport) { ProviderReportView() }
    }

    // MARK: - Components

    private func statCard(_ label: String, value: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.system(size: 22, weight: .medium, design: .monospaced))
                .foregroundStyle(.white)

            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.3))
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
                    .foregroundStyle(.white.opacity(0.5))
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
                    .foregroundStyle(.white.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.white.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(.white.opacity(0.06), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}
