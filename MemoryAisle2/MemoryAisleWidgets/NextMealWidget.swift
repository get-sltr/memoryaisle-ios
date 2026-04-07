import SwiftUI
import WidgetKit

struct NextMealEntry: TimelineEntry {
    let date: Date
    let mealName: String
    let mealTime: String
    let protein: Int
    let prepTime: String

    static let placeholder = NextMealEntry(
        date: .now,
        mealName: "Grilled Chicken Bowl",
        mealTime: "12:30 PM",
        protein: 42,
        prepTime: "15 min"
    )
}

struct NextMealProvider: TimelineProvider {
    func placeholder(in context: Context) -> NextMealEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (NextMealEntry) -> Void) {
        completion(.placeholder)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NextMealEntry>) -> Void) {
        let entry = NextMealEntry.placeholder
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: .now)!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct NextMealWidgetView: View {
    let entry: NextMealEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Next Meal")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(entry.mealTime)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Color(hex: 0xA78BFA).opacity(0.7))
            }

            Text(entry.mealName)
                .font(.system(size: 15, weight: .medium))
                .lineLimit(2)

            HStack(spacing: 12) {
                HStack(spacing: 3) {
                    Circle()
                        .fill(Color(hex: 0xA78BFA))
                        .frame(width: 4, height: 4)
                    Text("\(entry.protein)g protein")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 3) {
                    Image(systemName: "clock")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                    Text(entry.prepTime)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(14)
        .containerBackground(for: .widget) {
            Color(hex: 0x0A0914)
        }
    }
}

struct NextMealWidget: Widget {
    let kind = "NextMealWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NextMealProvider()) { entry in
            NextMealWidgetView(entry: entry)
        }
        .configurationDisplayName("Next Meal")
        .description("See your upcoming meal at a glance.")
        .supportedFamilies([.systemSmall])
    }
}
