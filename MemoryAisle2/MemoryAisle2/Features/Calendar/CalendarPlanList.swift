import SwiftUI

/// Editorial section views for the Calendar screen — planned meals list,
/// empty-day prompt, and the upcoming-holidays roll-up. Extracted to keep
/// `CalendarView.swift` under the 300-line cap.

struct CalendarPlannedMealsSection: View {
    let meals: [PlannedMeal]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MEAL PLAN")
                .font(Theme.Editorial.Typography.capsBold(10))
                .tracking(3)
                .foregroundStyle(Theme.Editorial.onSurface)
            HairlineDivider().opacity(0.5)
            VStack(spacing: 0) {
                ForEach(meals) { meal in
                    row(meal)
                    HairlineDivider().opacity(0.3)
                }
            }
        }
    }

    private func row(_ meal: PlannedMeal) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(meal.time.uppercased())
                .font(Theme.Editorial.Typography.caps(9, weight: .semibold))
                .tracking(1.5)
                .foregroundStyle(Theme.Editorial.onSurfaceFaint)
                .frame(width: 60, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(meal.name)
                    .font(Theme.Editorial.Typography.body())
                    .foregroundStyle(Theme.Editorial.onSurface)
                Text("\(meal.protein)G PROTEIN · \(meal.calories) CAL")
                    .font(Theme.Editorial.Typography.caps(9, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(Theme.Editorial.onSurfaceMuted)
            }

            Spacer()
        }
        .padding(.vertical, 12)
    }
}

struct CalendarEmptyPlan: View {
    let onGenerate: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 28))
                .foregroundStyle(Theme.Editorial.onSurfaceFaint)
            Text("NO MEAL PLAN FOR THIS DAY")
                .font(Theme.Editorial.Typography.caps(10, weight: .semibold))
                .tracking(2.2)
                .foregroundStyle(Theme.Editorial.onSurfaceMuted)
            Button { onGenerate() } label: {
                Text("GENERATE WITH MIRA")
                    .font(Theme.Editorial.Typography.capsBold(11))
                    .tracking(3)
                    .foregroundStyle(Theme.Editorial.onSurface)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .overlay(Capsule().stroke(Theme.Editorial.onSurface, lineWidth: 0.5))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

struct CalendarUpcomingHolidaysSection: View {
    let holidays: [Holiday]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("UPCOMING HOLIDAYS")
                .font(Theme.Editorial.Typography.capsBold(10))
                .tracking(3)
                .foregroundStyle(Theme.Editorial.onSurface)
            HairlineDivider().opacity(0.5)
            VStack(spacing: 0) {
                ForEach(holidays) { holiday in
                    CalendarHolidayRow(holiday: holiday)
                    HairlineDivider().opacity(0.3)
                }
            }
        }
    }
}

struct CalendarGeneratingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 18) {
                MiraWaveform(state: .thinking, size: .hero)
                    .frame(height: 50)
                Text("MIRA IS PLANNING YOUR MEALS")
                    .font(Theme.Editorial.Typography.capsBold(10))
                    .tracking(2.5)
                    .foregroundStyle(Theme.Editorial.onSurface)
                Text("This takes a few seconds")
                    .font(Theme.Editorial.Typography.body())
                    .foregroundStyle(Theme.Editorial.onSurfaceFaint)
            }
            .padding(28)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Theme.Editorial.hairline, lineWidth: 0.5)
            )
        }
    }
}
