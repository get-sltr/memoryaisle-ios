import SwiftUI

struct CalendarWeekStrip: View {
    @Environment(\.colorScheme) private var scheme
    @Binding var selectedDate: Date
    let generatedPlan: [Date: [PlannedMeal]]

    private let calendar = Calendar.current

    var body: some View {
        let today = Date.now
        let days = (-3...10).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: today)
        }

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(days, id: \.self) { day in
                    dayCell(day)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(day)
        let hasHoliday = HolidayCalendar.holidays().contains {
            calendar.isDate($0.date, inSameDayAs: day)
        }
        let hasPlan = generatedPlan[calendar.startOfDay(for: day)] != nil
        let rose = SectionPalette.primary(.calendar, for: scheme)

        return Button {
            HapticManager.selection()
            withAnimation(.easeOut(duration: 0.15)) {
                selectedDate = day
            }
        } label: {
            cellLabel(day: day, isSelected: isSelected, rose: rose, hasHoliday: hasHoliday, hasPlan: hasPlan)
                .frame(width: 46, height: 66)
                .background(cellBackground(isSelected: isSelected, isToday: isToday, rose: rose))
                .overlay(cellBorder(isSelected: isSelected, rose: rose))
                .shadow(color: isSelected ? rose.opacity(0.35) : .clear, radius: 10)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel(day, isSelected: isSelected, hasHoliday: hasHoliday, hasPlan: hasPlan))
    }

    private func cellLabel(day: Date, isSelected: Bool, rose: Color, hasHoliday: Bool, hasPlan: Bool) -> some View {
        VStack(spacing: 4) {
            Text(dayOfWeek(day))
                .font(Typography.label)
                .fontWeight(.medium)
                .foregroundStyle(
                    isSelected ? Color.white : Theme.Text.tertiary(for: scheme)
                )

            Text("\(calendar.component(.day, from: day))")
                .font(.system(size: 16, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(
                    isSelected ? Color.white : Theme.Text.secondary(for: scheme)
                )

            HStack(spacing: 2) {
                if hasHoliday {
                    Circle().fill(Theme.Semantic.fiber(for: scheme)).frame(width: 4, height: 4)
                }
                if hasPlan {
                    Circle().fill(isSelected ? .white : rose).frame(width: 4, height: 4)
                }
            }
            .frame(height: 4)
        }
    }

    @ViewBuilder
    private func cellBackground(isSelected: Bool, isToday: Bool, rose: Color) -> some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [rose, SectionPalette.mid(.calendar, for: scheme)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        } else if isToday {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.Section.glass(.calendar, for: scheme))
        } else {
            Color.clear
        }
    }

    @ViewBuilder
    private func cellBorder(isSelected: Bool, rose: Color) -> some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(rose.opacity(0.55), lineWidth: 0.5)
        }
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
