import SwiftData
import SwiftUI

struct JourneyProfileView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Query(sort: \NutritionLog.date, order: .reverse) private var logs: [NutritionLog]
    @State private var showPhotoCheckIn = false
    @State private var feelingToday: String?

    private var profile: UserProfile? { profiles.first }
    private var isOnMedication: Bool { profile?.medication != nil }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                headerSection
                weightRingSection
                calorieProteinCards
                calorieBreakdown
                mealSchedule

                if isOnMedication {
                    feelingSection
                }

                quickActions
                dailyMacros

                Spacer(minLength: 80)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
        }
        .themeBackground()
        .sheet(isPresented: $showPhotoCheckIn) { PhotoCheckInView() }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text("My journey")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.Text.tertiary(for: scheme))
                Spacer()
                Text("Edit")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(hex: 0x60A5FA))
            }
            .padding(.bottom, 18)

            HStack(spacing: 14) {
                // Avatar
                ZStack(alignment: .bottomTrailing) {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: 0x2A1A3A), Color(hex: 0x1A2A3A)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 68, height: 68)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(Theme.Text.tertiary(for: scheme))
                        )

                    Circle()
                        .fill(Color(hex: 0x60A5FA))
                        .frame(width: 22, height: 22)
                        .overlay(
                            Image(systemName: "camera.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(.white)
                        )
                        .offset(x: 2, y: 2)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(profile?.name.isEmpty == false ? profile!.name : "You")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Theme.Text.primary)

                    Text(isOnMedication ? "Wellness journey" : "Fitness journey")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.Text.tertiary(for: scheme))

                    HStack(spacing: 6) {
                        if isOnMedication {
                            badge("GLP-1", bg: Color(hex: 0x1A1A2E), fg: Color.violet)
                            if let weeks = medicationWeeks {
                                badge("Week \(weeks)", bg: Color(hex: 0x2A1A1A), fg: Color(hex: 0xF87171))
                            }
                        } else {
                            badge(modeBadgeText, bg: Color(hex: 0x1A2A1A), fg: Color(hex: 0x4ADE80))
                        }
                    }
                }

                Spacer()
            }
        }
    }

    // MARK: - Weight Ring

    private var weightRingSection: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(Color(hex: 0x1E1E30), lineWidth: 6)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: weightProgress)
                    .stroke(
                        isOnMedication ? Color.violet : Color(hex: 0x4ADE80),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text("\(Int(profile?.weightLbs ?? 0))")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(Theme.Text.primary)
                    Text("of \(Int(profile?.goalWeightLbs ?? 0)) lbs")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.Text.tertiary(for: scheme))
                }
            }

            if let current = profile?.weightLbs, let goal = profile?.goalWeightLbs {
                let diff = abs(Int(current - goal))
                Text("\(diff) lbs to go")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.Text.tertiary(for: scheme))
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Calorie + Protein Cards

    private var calorieProteinCards: some View {
        HStack(spacing: 8) {
            statCard(
                value: "\(profile?.calorieTarget ?? 1800)",
                label: "Daily calories",
                detail: calorieDetail,
                color: isOnMedication ? Color.violet : Color(hex: 0x60A5FA)
            )
            statCard(
                value: "\(profile?.proteinTargetGrams ?? 120)g",
                label: "Daily protein",
                detail: proteinDetail,
                color: isOnMedication ? Color(hex: 0x60A5FA) : Color(hex: 0xFBBF24)
            )
        }
    }

    // MARK: - Calorie Breakdown

    private var calorieBreakdown: some View {
        card {
            HStack {
                Text("CALORIE BREAKDOWN")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.Text.tertiary(for: scheme))
                    .tracking(0.8)
                Spacer()
                Text(isOnMedication ? "Deficit active" : "Surplus active")
                    .font(.system(size: 10))
                    .foregroundStyle(isOnMedication ? Color(hex: 0xF87171) : Color(hex: 0x4ADE80))
            }
            .padding(.bottom, 8)

            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(hex: 0x0E0E18))
                    .frame(height: 8)
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(isOnMedication ? Color.violet : Color(hex: 0x60A5FA))
                            .frame(width: geo.size.width * 0.75)
                    }
            }
            .frame(height: 8)
        }
    }

    // MARK: - Meal Schedule

    private var mealSchedule: some View {
        card {
            HStack {
                Text(isOnMedication ? "GLP-1 MEAL SCHEDULE" : "MEAL SCHEDULE")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.Text.tertiary(for: scheme))
                    .tracking(0.8)
                Spacer()
                Text(isOnMedication ? "3 meals + 1 snack" : "5 meals/day")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.violet)
            }
            .padding(.bottom, 8)

            let meals = isOnMedication
                ? [("Breakfast", "8:00 AM", 350), ("Lunch", "12:30 PM", 450), ("Snack", "3:30 PM", 150), ("Dinner", "6:30 PM", 450)]
                : [("Breakfast", "7:00 AM", 620), ("Snack", "10:00 AM", 400), ("Lunch", "12:30 PM", 700), ("Snack", "3:30 PM", 380), ("Dinner", "7:00 PM", 700)]

            VStack(spacing: 5) {
                ForEach(meals, id: \.0) { name, time, cal in
                    HStack {
                        Text(name)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.Text.primary)
                        Text(time)
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.Text.tertiary(for: scheme))
                        Spacer()
                        Text("\(cal) cal")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.violet)
                    }
                    .padding(.vertical, 7)
                    .padding(.horizontal, 10)
                    .background(Color(hex: 0x0E0E18))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            if isOnMedication {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 11))
                    Text("Eat protein first, then veggies, carbs last")
                        .font(.system(size: 11))
                }
                .foregroundStyle(Color.violet)
                .padding(8)
                .background(Color(hex: 0x1E1230))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.top, 6)
            }
        }
    }

    // MARK: - Feeling Section (medication only)

    private var feelingSection: some View {
        card {
            Text("HOW ARE YOU FEELING TODAY?")
                .font(.system(size: 11))
                .foregroundStyle(Theme.Text.tertiary(for: scheme))
                .tracking(0.8)
                .padding(.bottom, 6)

            HStack(spacing: 6) {
                feelingButton("Good", icon: "checkmark", color: Color(hex: 0x4ADE80), value: "good")
                feelingButton("Nausea", icon: "exclamationmark.triangle", color: Color(hex: 0xFBBF24), value: "nausea")
                feelingButton("No appetite", icon: "clock", color: Color(hex: 0x60A5FA), value: "no_appetite")
                feelingButton("Fatigue", icon: "bolt", color: Color(hex: 0xF87171), value: "fatigue")
            }
        }
    }

    private func feelingButton(_ label: String, icon: String, color: Color, value: String) -> some View {
        Button {
            HapticManager.selection()
            feelingToday = value
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(label)
                    .font(.system(size: 9))
            }
            .foregroundStyle(feelingToday == value ? color : Theme.Text.tertiary(for: scheme))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                feelingToday == value
                    ? color.opacity(0.1) : Color(hex: 0x0E0E18)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Quick Actions

    private var quickActions: some View {
        card {
            Text("QUICK ACTIONS")
                .font(.system(size: 11))
                .foregroundStyle(Theme.Text.tertiary(for: scheme))
                .tracking(0.8)
                .padding(.bottom, 8)

            VStack(spacing: 6) {
                actionRow("Log a meal", sub: "Snap a photo of your food", icon: "camera.fill", color: Color(hex: 0x4ADE80))
                actionRow("Scan barcode", sub: isOnMedication ? "Check if it works for you" : "Add food from packaging", icon: "barcode.viewfinder", color: Color(hex: 0x60A5FA))
                actionRow("Generate meal plan", sub: isOnMedication ? "Gentle recipes for your body" : "AI recipes for your goals", icon: "list.bullet.rectangle", color: Color(hex: 0xFBBF24))
                Button {
                    showPhotoCheckIn = true
                } label: {
                    actionRowContent("Weekly weigh-in", sub: "Track your progress", icon: "chart.line.uptrend.xyaxis", color: Color.violet)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func actionRow(_ title: String, sub: String, icon: String, color: Color) -> some View {
        HStack(spacing: 10) {
            actionRowContent(title, sub: sub, icon: icon, color: color)
        }
    }

    private func actionRowContent(_ title: String, sub: String, icon: String, color: Color) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.1))
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundStyle(color)
                )

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.Text.primary)
                Text(sub)
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.Text.tertiary(for: scheme))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 11))
                .foregroundStyle(Theme.Text.tertiary(for: scheme))
        }
        .padding(10)
        .background(Color(hex: 0x0E0E18))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Daily Macros

    private var dailyMacros: some View {
        card {
            Text("DAILY MACROS")
                .font(.system(size: 11))
                .foregroundStyle(Theme.Text.tertiary(for: scheme))
                .tracking(0.8)
                .padding(.bottom, 8)

            macroRow("Protein", value: "\(profile?.proteinTargetGrams ?? 120)g", color: Color(hex: 0x60A5FA))
            macroRow("Carbs", value: isOnMedication ? "120g" : "350g", color: Color(hex: 0xFBBF24))
            macroRow("Fat", value: isOnMedication ? "47g" : "93g", color: Color(hex: 0xF87171))
            macroRow("Fiber", value: "\(profile?.fiberTargetGrams ?? 25)g", color: Color(hex: 0x4ADE80))
            macroRow("Water", value: String(format: "%.1fL", profile?.waterTargetLiters ?? 2.5), color: Color(hex: 0x38BDF8), isLast: true)
        }
    }

    private func macroRow(_ label: String, value: String, color: Color, isLast: Bool = false) -> some View {
        HStack {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(Theme.Text.primary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.Text.primary)
        }
        .padding(.vertical, 6)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle()
                    .fill(Color(hex: 0x252538))
                    .frame(height: 0.5)
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func card(@ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(14)
        .background(Color(hex: 0x1A1A28))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func statCard(value: String, label: String, detail: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Theme.Text.tertiary(for: scheme))
            Text(detail)
                .font(.system(size: 10))
                .foregroundStyle(isOnMedication ? Color(hex: 0xF87171) : Color(hex: 0x4ADE80))
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color(hex: 0x1A1A28))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func badge(_ text: String, bg: Color, fg: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(fg)
            .padding(.horizontal, 10)
            .padding(.vertical, 2)
            .background(bg)
            .clipShape(Capsule())
    }

    private var weightProgress: Double {
        guard let current = profile?.weightLbs, let goal = profile?.goalWeightLbs, goal > 0 else { return 0 }
        if goal > current { return min(1.0, current / goal) }
        return min(1.0, goal / current)
    }

    private var calorieDetail: String {
        isOnMedication ? "-500 deficit" : "+500 surplus"
    }

    private var proteinDetail: String {
        isOnMedication ? "Preserve muscle" : "1g per lb goal"
    }

    private var modeBadgeText: String {
        switch profile?.productMode {
        case .musclePreservation: return "Lean gain"
        case .trainingPerformance: return "Performance"
        case .sensitiveStomach: return "Recovery"
        default: return "Everyday"
        }
    }

    private var medicationWeeks: Int? {
        guard isOnMedication else { return nil }
        return max(1, 8) // Would compute from medication start date
    }
}
