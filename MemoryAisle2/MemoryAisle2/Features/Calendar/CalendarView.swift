import SwiftData
import SwiftUI

struct CalendarView: View {
    var mode: MAMode = .auto

    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [UserProfile]
    @State private var selectedDate: Date = .now
    @State private var planDays: Int = 7
    @State private var viewMode: ViewMode = .week
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

    var body: some View {
        ZStack {
            EditorialBackground(mode: mode)

            VStack(alignment: .leading, spacing: 0) {
                topBar
                Masthead(wordmark: "CALENDAR", trailing: heroTrailing)
                    .padding(.bottom, 18)
                viewToggle
                    .padding(.bottom, 18)
                contentScroll
            }
            .padding(.horizontal, Theme.Editorial.Spacing.pad)
            .padding(.top, 12)
        }
        .preferredColorScheme(.light)
        .overlay { if isGenerating { CalendarGeneratingOverlay() } }
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

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 8) {
            Spacer()
            Button { showPlanGenerator = true } label: {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.Editorial.onSurface)
                    .frame(width: 32, height: 32)
                    .overlay(Circle().stroke(Theme.Editorial.hairline, lineWidth: 0.5))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Generate meal plan with Mira")

            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.Editorial.onSurface)
                    .frame(width: 32, height: 32)
                    .overlay(Circle().stroke(Theme.Editorial.hairline, lineWidth: 0.5))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
        .padding(.bottom, 14)
    }

    // MARK: - View toggle

    private var viewToggle: some View {
        HStack(spacing: 0) {
            toggleSegment(label: "WEEK", target: .week)
            toggleSegment(label: "MONTH", target: .month)
        }
        .padding(4)
        .overlay(Capsule().stroke(Theme.Editorial.hairline, lineWidth: 0.5))
        .clipShape(Capsule())
    }

    private func toggleSegment(label: String, target: ViewMode) -> some View {
        let isOn = viewMode == target
        return Button {
            HapticManager.light()
            withAnimation(.easeOut(duration: 0.15)) { viewMode = target }
        } label: {
            Text(label)
                .font(Theme.Editorial.Typography.caps(10, weight: .semibold))
                .tracking(2.5)
                .foregroundStyle(Theme.Editorial.onSurface)
                .frame(maxWidth: .infinity, minHeight: 32)
                .background(
                    Capsule().fill(isOn ? Theme.Editorial.onSurface.opacity(0.18) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: - Content scroll

    private var contentScroll: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                switch viewMode {
                case .week:
                    CalendarWeekStrip(selectedDate: $selectedDate, generatedPlan: generatedPlan)
                case .month:
                    CalendarMonthGrid(selectedDate: $selectedDate, generatedPlan: generatedPlan)
                }

                if !todayHolidays.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(todayHolidays) { CalendarHolidayCard(holiday: $0) }
                    }
                }

                if let meals = generatedPlan[Calendar.current.startOfDay(for: selectedDate)] {
                    CalendarPlannedMealsSection(meals: meals)
                } else {
                    CalendarEmptyPlan { showPlanGenerator = true }
                }

                if !upcomingHolidays.isEmpty {
                    CalendarUpcomingHolidaysSection(holidays: upcomingHolidays)
                }

                Spacer(minLength: 80)
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Hero trailing

    private var heroTrailing: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: selectedDate).uppercased()
    }

    // MARK: - Plan generation

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

    enum ViewMode { case week, month }
}
