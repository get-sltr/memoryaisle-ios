import SwiftUI

/// Editorial month grid for the Calendar screen. Seven-column `LazyVGrid` of
/// day cells for the month containing `selectedDate`. Days outside the month
/// are dimmed; days with a generated meal plan show a dot marker.
struct CalendarMonthGrid: View {
    @Binding var selectedDate: Date
    let generatedPlan: [Date: [PlannedMeal]]

    private let calendar = Calendar.current
    private let weekdaySymbols = ["S", "M", "T", "W", "T", "F", "S"]

    private let columns: [GridItem] = Array(
        repeating: GridItem(.flexible(), spacing: 4),
        count: 7
    )

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            monthHeader
            weekdayRow
            HairlineDivider().opacity(0.5)
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(daysInGrid, id: \.self) { day in
                    cell(for: day)
                }
            }
        }
    }

    // MARK: - Header

    private var monthHeader: some View {
        HStack {
            Button { stepMonth(by: -1) } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.Editorial.onSurfaceMuted)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Previous month")

            Spacer()

            Text(monthLabel)
                .font(Theme.Editorial.Typography.capsBold(11))
                .tracking(3)
                .textCase(.uppercase)
                .foregroundStyle(Theme.Editorial.onSurface)

            Spacer()

            Button { stepMonth(by: 1) } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.Editorial.onSurfaceMuted)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Next month")
        }
    }

    private var weekdayRow: some View {
        HStack(spacing: 4) {
            ForEach(0..<7, id: \.self) { index in
                Text(weekdaySymbols[index])
                    .font(Theme.Editorial.Typography.caps(9, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(Theme.Editorial.onSurfaceFaint)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Cell

    @ViewBuilder
    private func cell(for day: Date) -> some View {
        let isInMonth = calendar.isDate(day, equalTo: selectedDate, toGranularity: .month)
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(day)
        let hasPlan = generatedPlan[calendar.startOfDay(for: day)] != nil
        let dayNum = calendar.component(.day, from: day)

        Button {
            HapticManager.selection()
            withAnimation(.easeOut(duration: 0.15)) {
                selectedDate = day
            }
        } label: {
            VStack(spacing: 4) {
                Text("\(dayNum)")
                    .font(Theme.Editorial.Typography.body())
                    .foregroundStyle(
                        isInMonth ? Theme.Editorial.onSurface : Theme.Editorial.onSurfaceFaint
                    )
                Circle()
                    .fill(hasPlan ? Theme.Editorial.onSurface : Color.clear)
                    .frame(width: 4, height: 4)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Theme.Editorial.onSurface.opacity(0.18) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(
                        isToday && !isSelected ? Theme.Editorial.onSurface : Color.clear,
                        lineWidth: 0.5
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel(day, isSelected: isSelected, hasPlan: hasPlan))
    }

    // MARK: - Date helpers

    private var monthLabel: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: selectedDate)
    }

    private var daysInGrid: [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: selectedDate),
              let firstDay = calendar.dateInterval(of: .month, for: selectedDate)?.start else {
            return []
        }
        let firstWeekday = calendar.component(.weekday, from: firstDay)
        let leadingBlanks = firstWeekday - 1
        let monthDayCount = calendar.range(of: .day, in: .month, for: selectedDate)?.count ?? 30

        let totalCells = ((leadingBlanks + monthDayCount + 6) / 7) * 7
        let gridStart = calendar.date(byAdding: .day, value: -leadingBlanks, to: firstDay) ?? firstDay
        _ = monthInterval

        return (0..<totalCells).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: gridStart)
        }
    }

    private func stepMonth(by delta: Int) {
        guard let next = calendar.date(byAdding: .month, value: delta, to: selectedDate) else { return }
        HapticManager.light()
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedDate = next
        }
    }

    private func accessibilityLabel(_ day: Date, isSelected: Bool, hasPlan: Bool) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        var label = f.string(from: day)
        if isSelected { label += ", selected" }
        if hasPlan { label += ", meal plan available" }
        return label
    }
}
