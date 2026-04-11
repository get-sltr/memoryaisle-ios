import SwiftUI

struct CalendarHolidayCard: View {
    @Environment(\.colorScheme) private var scheme
    let holiday: Holiday

    var body: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(holiday.culture.emoji)
                        .font(.system(size: 16))
                    Text(holiday.name)
                        .font(Typography.bodyMediumBold)
                        .foregroundStyle(Theme.Text.primary)
                    Spacer()
                    if holiday.fasting {
                        Text("Fasting")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Theme.Semantic.fiber(for: scheme))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Theme.Semantic.fiber(for: scheme).opacity(0.12))
                            .clipShape(Capsule())
                    }
                }

                if let note = holiday.mealNote {
                    Text(note)
                        .font(Typography.bodySmall)
                        .foregroundStyle(Theme.Text.secondary(for: scheme))
                        .lineSpacing(3)
                }
            }
            .padding(14)
        }
        .padding(.horizontal, 20)
    }
}

struct CalendarHolidayRow: View {
    @Environment(\.colorScheme) private var scheme
    let holiday: Holiday

    private var formattedDate: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: holiday.date)
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(holiday.culture.emoji)
                .font(.system(size: 14))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(holiday.name)
                    .font(Typography.bodyMediumBold)
                    .foregroundStyle(Theme.Text.secondary(for: scheme))
                Text(formattedDate)
                    .font(Typography.caption)
                    .foregroundStyle(Theme.Text.tertiary(for: scheme))
            }

            Spacer()

            Text(holiday.culture.rawValue)
                .font(Typography.label)
                .fontWeight(.medium)
                .foregroundStyle(Color(hex: holiday.culture.color).opacity(0.7))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color(hex: holiday.culture.color).opacity(0.10))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 6)
    }
}
