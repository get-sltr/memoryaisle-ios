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
        VStack(spacing: 0) {
            // Header
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.violet.opacity(0.6))
                }
                Spacer()
                Text("Meal Calendar")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Theme.Text.primary)
                Spacer()
                Button { showPlanGenerator = true } label: {
                    Image(systemName: "sparkles")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color(hex: 0xA78BFA))
                        
                        .background(Circle().fill(Color(hex: 0xA78BFA).opacity(0.1)))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    // Week strip
                    weekStrip

                    // Holidays for selected date
                    if !todayHolidays.isEmpty {
                        ForEach(todayHolidays) { holiday in
                            holidayCard(holiday)
                        }
                    }

                    // Planned meals for selected date
                    if let meals = generatedPlan[Calendar.current.startOfDay(for: selectedDate)] {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("MEAL PLAN")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Theme.Text.tertiary(for: scheme))
                                .tracking(1.2)

                            ForEach(meals) { meal in
                                plannedMealCard(meal)
                            }
                        }
                        .padding(.horizontal, 20)
                    } else {
                        // No plan yet
                        VStack(spacing: 16) {
                            Image(systemName: "calendar.badge.plus")
                                .font(.system(size: 28))
                                .foregroundStyle(Theme.Text.tertiary(for: scheme))
                            Text("No meal plan for this day")
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.Text.tertiary(for: scheme))
                            GlowButton("Generate with Mira") {
                                showPlanGenerator = true
                            }
                            .padding(.horizontal, 50)
                        }
                        .padding(.top, 24)
                    }

                    // Upcoming holidays
                    if !upcomingHolidays.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("UPCOMING HOLIDAYS")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Theme.Text.tertiary(for: scheme))
                                .tracking(1.2)
                                .padding(.horizontal, 20)

                            ForEach(upcomingHolidays) { holiday in
                                holidayRow(holiday)
                            }
                        }
                        .padding(.top, 8)
                    }

                    Spacer(minLength: 40)
                }
                .padding(.top, 8)
            }
        }
        .themeBackground()
        .sheet(isPresented: $showPlanGenerator) {
            MealPlanGeneratorView(
                planDays: $planDays,
                onGenerate: { days in
                    generateMealPlan(days: days)
                }
            )
        }
    }

    // MARK: - Week Strip

    private var weekStrip: some View {
        let calendar = Calendar.current
        let today = Date.now
        let days = (-3...10).map { offset in
            calendar.date(byAdding: .day, value: offset, to: today)!
        }

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(days, id: \.self) { day in
                    let isSelected = calendar.isDate(day, inSameDayAs: selectedDate)
                    let isToday = calendar.isDateInToday(day)
                    let hasHoliday = HolidayCalendar.holidays().contains { calendar.isDate($0.date, inSameDayAs: day) }
                    let hasPlan = generatedPlan[calendar.startOfDay(for: day)] != nil

                    Button {
                        HapticManager.selection()
                        withAnimation(.easeOut(duration: 0.15)) {
                            selectedDate = day
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Text(dayOfWeek(day))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(isSelected ? Theme.Text.primary : Theme.Text.tertiary(for: scheme))

                            Text("\(calendar.component(.day, from: day))")
                                .font(.system(size: 16, weight: isSelected ? .semibold : .regular))
                                .foregroundStyle(isSelected ? Theme.Text.primary : Theme.Text.secondary(for: scheme))

                            // Dots for holidays/plans
                            HStack(spacing: 2) {
                                if hasHoliday {
                                    Circle().fill(Color(hex: 0xFBBF24)).frame(width: 4, height: 4)
                                }
                                if hasPlan {
                                    Circle().fill(Color(hex: 0xA78BFA)).frame(width: 4, height: 4)
                                }
                            }
                            .frame(height: 4)
                        }
                        .frame(width: 44, height: 64)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(isSelected ? Color(hex: 0xA78BFA).opacity(0.2) : isToday ? Theme.Surface.glass(for: scheme) : .clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(isSelected ? Color(hex: 0xA78BFA).opacity(0.3) : .clear, lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Holiday Card

    private func holidayCard(_ holiday: Holiday) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(holiday.culture.emoji)
                    .font(.system(size: 16))
                Text(holiday.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.Text.primary)
                Spacer()
                if holiday.fasting {
                    Text("Fasting")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color(hex: 0xFBBF24))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(hex: 0xFBBF24).opacity(0.1))
                        .clipShape(Capsule())
                }
            }

            if let note = holiday.mealNote {
                Text(note)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.Text.secondary(for: scheme))
                    .lineSpacing(3)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(hex: holiday.culture.color).opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(hex: holiday.culture.color).opacity(0.12), lineWidth: 0.5)
        )
        .padding(.horizontal, 20)
    }

    // MARK: - Holiday Row (upcoming list)

    private func holidayRow(_ holiday: Holiday) -> some View {
        HStack(spacing: 10) {
            Text(holiday.culture.emoji)
                .font(.system(size: 14))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(holiday.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.Text.secondary(for: scheme))
                Text(formatDate(holiday.date))
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.Text.tertiary(for: scheme))
            }

            Spacer()

            Text(holiday.culture.rawValue)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color(hex: holiday.culture.color).opacity(0.6))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color(hex: holiday.culture.color).opacity(0.08))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 6)
    }

    // MARK: - Planned Meal Card

    private func plannedMealCard(_ meal: PlannedMeal) -> some View {
        HStack(spacing: 10) {
            Text(meal.time)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Theme.Text.tertiary(for: scheme))
                .frame(width: 50, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(meal.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.Text.primary)
                Text("\(meal.protein)g protein · \(meal.calories) cal")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color(hex: 0xA78BFA).opacity(0.5))
            }

            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.Surface.glass(for: scheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Theme.Border.glass(for: scheme), lineWidth: Theme.glassBorderWidth)
        )
    }

    // MARK: - Helpers

    private func dayOfWeek(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f.string(from: date).uppercased()
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: date)
    }

    // MARK: - Plan Generator

    private func generateMealPlan(days: Int) {
        let calendar = Calendar.current
        let meals = ["Protein Oats", "Chicken Bowl", "Salmon Dinner", "Greek Yogurt"]
        let proteins = [32, 45, 38, 24]
        let cals = [380, 580, 520, 220]
        let times = ["8:30 AM", "12:30 PM", "6:00 PM", "Snack"]

        for offset in 0..<days {
            let day = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: selectedDate))!
            var dayMeals: [PlannedMeal] = []
            for i in 0..<4 {
                dayMeals.append(PlannedMeal(
                    time: times[i],
                    name: meals[i],
                    protein: proteins[i],
                    calories: cals[i]
                ))
            }
            generatedPlan[day] = dayMeals
        }
        HapticManager.success()
    }
}

struct PlannedMeal: Identifiable {
    let id = UUID()
    let time: String
    let name: String
    let protein: Int
    let calories: Int
}

// MARK: - Meal Plan Generator Sheet

struct MealPlanGeneratorView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @Binding var planDays: Int

    let onGenerate: (Int) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.violet.opacity(0.6))
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            Spacer()

            MiraWaveform(state: .speaking, size: .hero)
                .frame(height: 60)
                .padding(.bottom, 28)

            Text("Generate meal plan")
                .font(.system(size: 24, weight: .light, design: .serif))
                .foregroundStyle(Theme.Text.primary)
                .tracking(0.3)

            Text("Mira will create a personalized plan\nbased on your profile and goals.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.Text.tertiary(for: scheme))
                .multilineTextAlignment(.center)
                .padding(.top, 8)
                .padding(.bottom, 32)

            // Day selector
            VStack(spacing: 10) {
                Text("HOW MANY DAYS")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Theme.Text.tertiary(for: scheme))
                    .tracking(1.2)

                HStack(spacing: 6) {
                    ForEach([1, 3, 5, 7, 14], id: \.self) { days in
                        let isSelected = planDays == days

                        Button {
                            HapticManager.selection()
                            planDays = days
                        } label: {
                            Text("\(days)")
                                .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                                .foregroundStyle(isSelected ? Theme.Text.primary : Theme.Text.secondary(for: scheme))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(isSelected ? Color(hex: 0xA78BFA).opacity(0.2) : Theme.Surface.glass(for: scheme))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(isSelected ? Color(hex: 0xA78BFA).opacity(0.3) : .clear, lineWidth: 0.5)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 28)
            }

            Spacer()

            GlowButton("Generate \(planDays)-day plan") {
                onGenerate(planDays)
                dismiss()
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 56)
        }
        .themeBackground()
    }
}
