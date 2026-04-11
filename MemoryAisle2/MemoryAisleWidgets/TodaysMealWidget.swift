import SwiftUI
import WidgetKit

struct MealEntry: TimelineEntry {
    let date: Date
    let mealName: String?
    let mealType: String?
    let protein: Int
    let calories: Int
    let prepMinutes: Int
    let isNauseaSafe: Bool
}

struct MealProvider: TimelineProvider {
    func placeholder(in context: Context) -> MealEntry {
        MealEntry(
            date: .now, mealName: "Grilled Chicken Bowl",
            mealType: "Lunch", protein: 42, calories: 520,
            prepMinutes: 15, isNauseaSafe: false
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (MealEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MealEntry>) -> Void) {
        Task { @MainActor in
            let meal = AppGroupDataProvider.nextMeal()
            let entry = MealEntry(
                date: .now,
                mealName: meal?.name,
                mealType: meal?.mealType.rawValue,
                protein: Int(meal?.proteinGrams ?? 0),
                calories: Int(meal?.caloriesTotal ?? 0),
                prepMinutes: meal?.prepTimeMinutes ?? 0,
                isNauseaSafe: meal?.isNauseaSafe ?? false
            )
            let nextUpdate = Calendar.current.date(
                byAdding: .minute, value: 15, to: .now
            ) ?? .now
            completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
        }
    }
}

struct TodaysMealWidgetView: View {
    let entry: MealEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        if let name = entry.mealName {
            VStack(alignment: .leading, spacing: 6) {
                if let type = entry.mealType {
                    Text(type.uppercased())
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .tracking(0.5)
                }

                Text(name)
                    .font(.system(size: 15, weight: .medium))
                    .lineLimit(2)

                HStack(spacing: 12) {
                    Label("\(entry.protein)g", systemImage: "flame.fill")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color(red: 0.655, green: 0.545, blue: 0.98))
                    Label("\(entry.calories)", systemImage: "bolt.fill")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    if entry.prepMinutes > 0 {
                        Text("\(entry.prepMinutes) min")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                    if entry.isNauseaSafe {
                        Label("Nausea-safe", systemImage: "leaf.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Color(red: 0.204, green: 0.827, blue: 0.6))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .containerBackground(.fill.tertiary, for: .widget)
        } else {
            VStack(spacing: 8) {
                Image(systemName: "fork.knife")
                    .font(.system(size: 24))
                    .foregroundStyle(.secondary)
                Text("No meal plan")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Text("Open MemoryAisle to generate")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity)
            .containerBackground(.fill.tertiary, for: .widget)
        }
    }
}

struct TodaysMealWidget: Widget {
    let kind = "TodaysMealWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MealProvider()) { entry in
            TodaysMealWidgetView(entry: entry)
        }
        .configurationDisplayName("Next Meal")
        .description("See your next meal from today's plan")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
