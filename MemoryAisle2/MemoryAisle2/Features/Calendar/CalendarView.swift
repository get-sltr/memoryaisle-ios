import SwiftData
import SwiftUI

struct CalendarView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [UserProfile]
    @State private var selectedDate: Date = .now
    @State private var planDays: Int = 7
    @State private var showPlanGenerator = false
    @State private var generatedPlan: [Date: [PlannedMeal]] = [:]
    @State private var isGenerating = false
    @State private var generationError: String?

    private var profile: UserProfile? { profiles.first }

    private var todayHolidays: [Holiday] {
        HolidayCalendar.holidays().filter {
            Calendar.current.isDate($0.date, inSameDayAs: selectedDate)
        }
    }

    private var upcomingHolidays: [Holiday] {
        HolidayCalendar.upcoming(days: 14)
    }

    private var heroSubtitle: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f.string(from: selectedDate)
    }

    var body: some View {
        VStack(spacing: 0) {
            HeroHeader(title: "Calendar", subtitle: heroSubtitle) {
                HStack(spacing: 8) {
                    IconButton(
                        systemName: "sparkles",
                        accessibilityLabel: "Generate meal plan with Mira"
                    ) {
                        showPlanGenerator = true
                    }
                    CloseButton(action: { dismiss() })
                }
            }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    CalendarWeekStrip(
                        selectedDate: $selectedDate,
                        generatedPlan: generatedPlan
                    )

                    if !todayHolidays.isEmpty {
                        ForEach(todayHolidays) { holiday in
                            CalendarHolidayCard(holiday: holiday)
                        }
                    }

                    if let meals = generatedPlan[Calendar.current.startOfDay(for: selectedDate)] {
                        plannedMealsSection(meals)
                    } else {
                        emptyPlan
                    }

                    if !upcomingHolidays.isEmpty {
                        upcomingHolidaysSection
                    }

                    Spacer(minLength: 40)
                }
                .padding(.top, 18)
            }
        }
        .section(.calendar)
        .themeBackground()
        .overlay {
            if isGenerating {
                generatingOverlay
            }
        }
        .alert(
            "Couldn't Generate Plan",
            isPresented: Binding(
                get: { generationError != nil },
                set: { if !$0 { generationError = nil } }
            ),
            presenting: generationError
        ) { _ in
            Button("OK", role: .cancel) { generationError = nil }
        } message: { error in
            Text(error)
        }
        .sheet(isPresented: $showPlanGenerator) {
            MealPlanGeneratorView(
                planDays: $planDays,
                onGenerate: { days in
                    generateMealPlan(days: days)
                }
            )
        }
    }

    // MARK: - Overlays

    private var generatingOverlay: some View {
        ZStack {
            Theme.background(for: scheme).opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                MiraWaveform(state: .thinking, size: .hero)
                    .frame(height: 50)

                Text("Mira is planning your meals…")
                    .font(Typography.bodyMedium)
                    .foregroundStyle(Theme.Text.primary)

                Text("This takes a few seconds")
                    .font(Typography.bodySmall)
                    .foregroundStyle(Theme.Text.tertiary(for: scheme))
            }
            .padding(32)
            .background(Theme.Surface.strong(for: scheme))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Theme.Section.border(.calendar, for: scheme), lineWidth: Theme.glassBorderWidth)
            )
        }
    }

    // MARK: - Planned meals

    private func plannedMealsSection(_ meals: [PlannedMeal]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("MEAL PLAN")
                .font(Typography.label)
                .fontWeight(.medium)
                .foregroundStyle(SectionPalette.soft(.calendar))
                .tracking(1.2)

            ForEach(meals) { meal in
                plannedMealCard(meal)
            }
        }
        .padding(.horizontal, 20)
    }

    private func plannedMealCard(_ meal: PlannedMeal) -> some View {
        SectionCard {
            HStack(spacing: 10) {
                Text(meal.time)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Theme.Text.tertiary(for: scheme))
                    .frame(width: 54, alignment: .leading)

                VStack(alignment: .leading, spacing: 2) {
                    Text(meal.name)
                        .font(Typography.bodyMediumBold)
                        .foregroundStyle(Theme.Text.primary)
                    Text("\(meal.protein)g protein · \(meal.calories) cal")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(SectionPalette.primary(.calendar, for: scheme).opacity(0.75))
                }

                Spacer()
            }
            .padding(14)
        }
    }

    private var emptyPlan: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 32))
                .foregroundStyle(SectionPalette.primary(.calendar, for: scheme).opacity(0.35))
            Text("No meal plan for this day")
                .font(Typography.bodySmall)
                .foregroundStyle(Theme.Text.tertiary(for: scheme))
            GlowButton("Generate with Mira", icon: "sparkles") {
                showPlanGenerator = true
            }
            .padding(.horizontal, 50)
        }
        .padding(.top, 16)
    }

    // MARK: - Upcoming holidays

    private var upcomingHolidaysSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("UPCOMING HOLIDAYS")
                .font(Typography.label)
                .fontWeight(.medium)
                .foregroundStyle(SectionPalette.soft(.calendar))
                .tracking(1.2)
                .padding(.horizontal, 20)

            ForEach(upcomingHolidays) { holiday in
                CalendarHolidayRow(holiday: holiday)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Plan Generation

    private func generateMealPlan(days: Int) {
        guard let profile = profiles.first else {
            generationError = "No profile found. Complete onboarding first."
            return
        }

        isGenerating = true
        generationError = nil

        Task {
            do {
                let plan = try await MealPlanGenerator.fetchPlan(
                    days: days,
                    profile: profile,
                    startDate: selectedDate
                )
                await MainActor.run {
                    self.generatedPlan = plan
                    self.isGenerating = false
                    HapticManager.success()
                }
            } catch {
                await MainActor.run {
                    self.generationError = "Couldn't generate meal plan. \(error.localizedDescription)"
                    self.isGenerating = false
                }
            }
        }
    }
}
