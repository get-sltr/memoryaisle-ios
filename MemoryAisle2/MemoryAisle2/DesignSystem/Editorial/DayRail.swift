import SwiftUI

enum Weekday: String, CaseIterable, Identifiable, Sendable {
    case mon, tue, wed, thu, fri, sat, sun

    var id: String { rawValue }
    var label: String { rawValue.uppercased() }

    /// Calendar weekday (1=Sun, 2=Mon, ..., 7=Sat) so we can map to/from `Date`.
    var calendarWeekday: Int {
        switch self {
        case .sun: 1
        case .mon: 2
        case .tue: 3
        case .wed: 4
        case .thu: 5
        case .fri: 6
        case .sat: 7
        }
    }

    static func from(date: Date, calendar: Calendar = .current) -> Weekday {
        let weekday = calendar.component(.weekday, from: date)
        return Weekday.allCases.first { $0.calendarWeekday == weekday } ?? .mon
    }
}

struct DayRail: View {
    @Binding var selection: Weekday

    var body: some View {
        VStack(spacing: 0) {
            HairlineDivider()
            HStack(spacing: 0) {
                ForEach(Weekday.allCases) { day in
                    Button {
                        HapticManager.selection()
                        selection = day
                    } label: {
                        VStack(spacing: 4) {
                            Text(day.label)
                                .font(Theme.Editorial.Typography.capsBold(10))
                                .tracking(1)
                                .foregroundStyle(Theme.Editorial.onSurface)
                                .opacity(selection == day ? 1.0 : 0.55)
                            if selection == day {
                                Circle()
                                    .fill(Theme.Editorial.onSurface)
                                    .frame(width: 4, height: 4)
                            } else {
                                Color.clear.frame(width: 4, height: 4)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(day.label)
                    .accessibilityAddTraits(selection == day ? [.isSelected, .isButton] : .isButton)
                }
            }
            .padding(.vertical, 12)
            HairlineDivider()
        }
    }
}
