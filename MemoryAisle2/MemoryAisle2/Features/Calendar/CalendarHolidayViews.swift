import SwiftUI

struct CalendarHolidayCard: View {
    let holiday: Holiday

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(holiday.culture.emoji)
                    .font(.system(size: 16))
                Text(holiday.name.uppercased())
                    .font(Theme.Editorial.Typography.capsBold(11))
                    .tracking(2)
                    .foregroundStyle(Theme.Editorial.onSurface)
                Spacer()
                if holiday.fasting {
                    Text("FASTING")
                        .font(Theme.Editorial.Typography.caps(9, weight: .semibold))
                        .tracking(1.6)
                        .foregroundStyle(Theme.Editorial.onSurface)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .overlay(Capsule().stroke(Theme.Editorial.hairline, lineWidth: 0.5))
                }
            }

            if let note = holiday.mealNote {
                Text(note)
                    .font(Theme.Editorial.Typography.body())
                    .foregroundStyle(Theme.Editorial.onSurfaceMuted)
                    .lineSpacing(3)
            }

            HairlineDivider().opacity(0.4)
        }
    }
}

struct CalendarHolidayRow: View {
    let holiday: Holiday

    private var formattedDate: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: holiday.date)
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(holiday.culture.emoji)
                .font(.system(size: 14))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(holiday.name)
                    .font(Theme.Editorial.Typography.body())
                    .foregroundStyle(Theme.Editorial.onSurface)
                Text(formattedDate.uppercased())
                    .font(Theme.Editorial.Typography.caps(9, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(Theme.Editorial.onSurfaceFaint)
            }

            Spacer()

            Text(holiday.culture.rawValue.uppercased())
                .font(Theme.Editorial.Typography.caps(9, weight: .semibold))
                .tracking(1.5)
                .foregroundStyle(Theme.Editorial.onSurfaceMuted)
        }
        .padding(.vertical, 8)
    }
}
