import SwiftUI

struct CalendarWeekStrip: View {
    @Binding var selectedDate: Date
    let generatedPlan: [Date: [PlannedMeal]]

    private let calendar = Calendar.current

    var body: some View {
        let today = Date.now
        let days = (-3...10).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: today)
        }

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(days, id: \.self) { day in
                    dayCell(day)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(day)
        let hasHoliday = HolidayCalendar.holidays().contains {
            calendar.isDate($0.date, inSameDayAs: day)
        }
        let hasPlan = generatedPlan[calendar.startOfDay(for: day)] != nil

        return Button {
            HapticManager.selection()
            withAnimation(.easeOut(duration: 0.15)) {
                selectedDate = day
            }
        } label: {
            VStack(spacing: 6) {
                Text(dayOfWeek(day))
                    .font(Theme.Editorial.Typography.caps(9, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(
                        isSelected ? Theme.Editorial.onSurface : Theme.Editorial.onSurfaceFaint
                    )

                Text("\(calendar.component(.day, from: day))")
                    .font(Theme.Editorial.Typography.body())
                    .foregroundStyle(Theme.Editorial.onSurface)

                HStack(spacing: 3) {
                    if hasHoliday {
                        Circle().fill(Theme.Editorial.onSurfaceMuted).frame(width: 4, height: 4)
                    }
                    if hasPlan {
                        Circle().fill(Theme.Editorial.onSurface).frame(width: 4, height: 4)
                    }
                }
                .frame(height: 4)
            }
            .frame(width: 50, height: 72)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Theme.Editorial.onSurface.opacity(0.18) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        isToday && !isSelected ? Theme.Editorial.onSurface : Color.clear,
                        lineWidth: 0.5
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel(day, isSelected: isSelected, hasHoliday: hasHoliday, hasPlan: hasPlan))
    }

    private func dayOfWeek(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f.string(from: date).uppercased()
    }

    private func accessibilityLabel(_ day: Date, isSelected: Bool, hasHoliday: Bool, hasPlan: Bool) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        var label = f.string(from: day)
        if isSelected { label += ", selected" }
        if hasHoliday { label += ", holiday" }
        if hasPlan { label += ", meal plan available" }
        return label
    }
}
