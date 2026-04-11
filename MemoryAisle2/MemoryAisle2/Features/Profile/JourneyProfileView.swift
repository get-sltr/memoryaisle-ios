import SwiftData
import SwiftUI

struct JourneyProfileView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Query(sort: \NutritionLog.date, order: .reverse) private var logs: [NutritionLog]
    @State private var showPhotoCheckIn = false
    @State private var showLogMeal = false
    @State private var showScanBarcode = false
    @State private var showMealPlan = false
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
        .section(.home)
        .themeBackground()
        .sheet(isPresented: $showPhotoCheckIn) { PhotoCheckInView() }
        .sheet(isPresented: $showLogMeal) { MealPhotoView() }
        .sheet(isPresented: $showScanBarcode) { ScanView() }
        .sheet(isPresented: $showMealPlan) { CalendarView() }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 0) {
            HStack {
                CloseButton(action: { dismiss() })
                Spacer()
                Text("My journey")
                    .font(Typography.bodySmall)
                    .foregroundStyle(Theme.Text.tertiary(for: scheme))
                Spacer()
                Color.clear
                    .frame(width: 14, height: 14)
            }
            .padding(.bottom, 18)

            journeyCard
        }
    }

    // MARK: - Journey Card (avatar + name + journey + badges in one big card)

    private var journeyCard: some View {
        SectionCard {
            HStack(spacing: 16) {
                JourneyAvatarButton()

                VStack(alignment: .leading, spacing: 5) {
                    Text(profile?.name.isEmpty == false ? (profile?.name ?? "You") : "You")
                        .font(Typography.titleSmall)
                        .foregroundStyle(Theme.Text.primary)

                    Text(isOnMedication ? "Wellness journey" : "Fitness journey")
                        .font(Typography.bodySmall)
                        .foregroundStyle(Theme.Text.tertiary(for: scheme))

                    HStack(spacing: 6) {
                        if isOnMedication {
                            badge("GLP-1", bg: Theme.Surface.glass(for: scheme), fg: Color.violet)
                            if let weeks = medicationWeeks {
                                badge(
                                    "Week \(weeks)",
                                    bg: Theme.Semantic.warning(for: scheme).opacity(0.12),
                                    fg: Theme.Semantic.warning(for: scheme)
                                )
                            }
                        } else {
                            badge(
                                modeBadgeText,
                                bg: Theme.Semantic.success(for: scheme).opacity(0.12),
                                fg: Theme.Semantic.success(for: scheme)
                            )
                        }
                    }
                    .padding(.top, 2)
                }

                Spacer()
            }
            .padding(18)
        }
    }

    // MARK: - Weight Ring

    private var weightRingSection: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(Theme.Surface.strong(for: scheme), lineWidth: 6)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: weightProgress)
                    .stroke(
                        isOnMedication ? Color.violet : Theme.Semantic.success(for: scheme),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text("\(Int(profile?.weightLbs ?? 0))")
                        .font(Typography.displayMedium)
                        .foregroundStyle(Theme.Text.primary)
                    Text("of \(Int(profile?.goalWeightLbs ?? 0)) lbs")
                        .font(Typography.label)
                        .foregroundStyle(Theme.Text.tertiary(for: scheme))
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Current weight \(Int(profile?.weightLbs ?? 0)) pounds of \(Int(profile?.goalWeightLbs ?? 0)) pound goal")

            if let current = profile?.weightLbs, let goal = profile?.goalWeightLbs {
                let diff = abs(Int(current - goal))
                Text("\(diff) lbs to go")
                    .font(Typography.bodySmall)
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
                color: isOnMedication ? Color.violet : Theme.Semantic.info(for: scheme)
            )
            statCard(
                value: "\(profile?.proteinTargetGrams ?? 120)g",
                label: "Daily protein",
                detail: proteinDetail,
                color: isOnMedication ? Theme.Semantic.info(for: scheme) : Theme.Semantic.fiber(for: scheme)
            )
        }
    }

    // MARK: - Calorie Breakdown

    private var calorieBreakdown: some View {
        card {
            HStack {
                Text("CALORIE BREAKDOWN")
                    .font(Typography.caption)
                    .foregroundStyle(Theme.Text.tertiary(for: scheme))
                    .tracking(0.8)
                Spacer()
                Text(isOnMedication ? "Deficit active" : "Surplus active")
                    .font(Typography.label)
                    .foregroundStyle(
                        isOnMedication
                            ? Theme.Semantic.warning(for: scheme)
                            : Theme.Semantic.success(for: scheme)
                    )
            }
            .padding(.bottom, 8)

            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 4)
                    .fill(Theme.Surface.glass(for: scheme))
                    .frame(height: 8)
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(isOnMedication ? Color.violet : Theme.Semantic.info(for: scheme))
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
                    .font(Typography.caption)
                    .foregroundStyle(Theme.Text.tertiary(for: scheme))
                    .tracking(0.8)
                Spacer()
                Text(isOnMedication ? "3 meals + 1 snack" : "5 meals/day")
                    .font(Typography.label)
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
                            .font(Typography.bodySmallBold)
                            .foregroundStyle(Theme.Text.primary)
                        Text(time)
                            .font(Typography.label)
                            .foregroundStyle(Theme.Text.tertiary(for: scheme))
                        Spacer()
                        Text("\(cal) cal")
                            .font(Typography.bodySmallBold)
                            .foregroundStyle(Color.violet)
                    }
                    .padding(.vertical, 7)
                    .padding(.horizontal, 10)
                    .background(Theme.Surface.glass(for: scheme))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Theme.Border.glass(for: scheme), lineWidth: Theme.glassBorderWidth)
                    )
                }
            }

            if isOnMedication {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(Typography.caption)
                    Text("Eat protein first, then veggies, carbs last")
                        .font(Typography.caption)
                }
                .foregroundStyle(Color.violet)
                .padding(8)
                .background(Theme.Surface.strong(for: scheme))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Theme.Border.glass(for: scheme), lineWidth: Theme.glassBorderWidth)
                )
                .padding(.top, 6)
            }
        }
    }

    // MARK: - Feeling Section (medication only)

    private var feelingSection: some View {
        card {
            Text("HOW ARE YOU FEELING TODAY?")
                .font(Typography.caption)
                .foregroundStyle(Theme.Text.tertiary(for: scheme))
                .tracking(0.8)
                .padding(.bottom, 6)

            HStack(spacing: 6) {
                feelingButton("Good", icon: "checkmark", color: Theme.Semantic.success(for: scheme), value: "good")
                feelingButton("Nausea", icon: "exclamationmark.triangle", color: Theme.Semantic.fiber(for: scheme), value: "nausea")
                feelingButton("No appetite", icon: "clock", color: Theme.Semantic.info(for: scheme), value: "no_appetite")
                feelingButton("Fatigue", icon: "bolt", color: Theme.Semantic.warning(for: scheme), value: "fatigue")
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
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.vertical, 8)
            .background(
                feelingToday == value
                    ? color.opacity(0.15) : Theme.Surface.glass(for: scheme)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Theme.Border.glass(for: scheme), lineWidth: Theme.glassBorderWidth)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Feeling \(label)")
        .accessibilityHint("Log how you are feeling today")
        .accessibilityAddTraits(feelingToday == value ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: - Quick Actions

    private var quickActions: some View {
        card {
            Text("QUICK ACTIONS")
                .font(Typography.caption)
                .foregroundStyle(Theme.Text.tertiary(for: scheme))
                .tracking(0.8)
                .padding(.bottom, 8)

            VStack(spacing: 6) {
                actionButton(
                    "Log a meal",
                    sub: "Snap a photo of your food",
                    icon: "camera.fill",
                    color: Theme.Semantic.success(for: scheme)
                ) { showLogMeal = true }

                actionButton(
                    "Scan barcode",
                    sub: isOnMedication ? "Check if it works for you" : "Add food from packaging",
                    icon: "barcode.viewfinder",
                    color: Theme.Semantic.info(for: scheme)
                ) { showScanBarcode = true }

                actionButton(
                    "Generate meal plan",
                    sub: isOnMedication ? "Gentle recipes for your body" : "AI recipes for your goals",
                    icon: "list.bullet.rectangle",
                    color: Theme.Semantic.fiber(for: scheme)
                ) { showMealPlan = true }

                actionButton(
                    "Weekly weigh-in",
                    sub: "Track your progress",
                    icon: "chart.line.uptrend.xyaxis",
                    color: Color.violet
                ) { showPhotoCheckIn = true }
            }
        }
    }

    private func actionButton(
        _ title: String,
        sub: String,
        icon: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            HapticManager.light()
            action()
        } label: {
            actionRowContent(title, sub: sub, icon: icon, color: color)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint(sub)
    }

    private func actionRowContent(_ title: String, sub: String, icon: String, color: Color) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.12))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundStyle(color)
                )

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(Typography.bodySmallBold)
                    .foregroundStyle(Theme.Text.primary)
                Text(sub)
                    .font(Typography.label)
                    .foregroundStyle(Theme.Text.tertiary(for: scheme))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(Typography.caption)
                .foregroundStyle(Theme.Text.tertiary(for: scheme))
        }
        .padding(10)
        .frame(minHeight: 44)
        .background(Theme.Surface.glass(for: scheme))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Theme.Border.glass(for: scheme), lineWidth: Theme.glassBorderWidth)
        )
    }

    // MARK: - Daily Macros

    private var dailyMacros: some View {
        card {
            Text("DAILY MACROS")
                .font(Typography.caption)
                .foregroundStyle(Theme.Text.tertiary(for: scheme))
                .tracking(0.8)
                .padding(.bottom, 8)

            macroRow("Protein", value: "\(profile?.proteinTargetGrams ?? 120)g", color: Theme.Semantic.info(for: scheme))
            macroRow("Carbs", value: isOnMedication ? "120g" : "350g", color: Theme.Semantic.fiber(for: scheme))
            macroRow("Fat", value: isOnMedication ? "47g" : "93g", color: Theme.Semantic.warning(for: scheme))
            macroRow("Fiber", value: "\(profile?.fiberTargetGrams ?? 25)g", color: Theme.Semantic.success(for: scheme))
            macroRow("Water", value: String(format: "%.1fL", profile?.waterTargetLiters ?? 2.5), color: Theme.Semantic.water(for: scheme), isLast: true)
        }
    }

    private func macroRow(_ label: String, value: String, color: Color, isLast: Bool = false) -> some View {
        HStack {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
                .font(Typography.bodySmall)
                .foregroundStyle(Theme.Text.primary)
            Spacer()
            Text(value)
                .font(Typography.bodySmallBold)
                .foregroundStyle(Theme.Text.primary)
        }
        .padding(.vertical, 6)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle()
                    .fill(Theme.Border.glass(for: scheme))
                    .frame(height: 0.5)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    // MARK: - Helpers

    @ViewBuilder
    private func card(@ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(14)
        .background(Theme.Surface.glass(for: scheme))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.Border.glass(for: scheme), lineWidth: Theme.glassBorderWidth)
        )
    }

    private func statCard(value: String, label: String, detail: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(Typography.titleLarge)
                .foregroundStyle(color)
            Text(label)
                .font(Typography.caption)
                .foregroundStyle(Theme.Text.tertiary(for: scheme))
            Text(detail)
                .font(Typography.label)
                .foregroundStyle(
                    isOnMedication
                        ? Theme.Semantic.warning(for: scheme)
                        : Theme.Semantic.success(for: scheme)
                )
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Theme.Surface.glass(for: scheme))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Theme.Border.glass(for: scheme), lineWidth: Theme.glassBorderWidth)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value), \(detail)")
    }

    private func badge(_ text: String, bg: Color, fg: Color) -> some View {
        Text(text)
            .font(Typography.label)
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
