import SwiftUI
import WidgetKit

struct HydrationEntry: TimelineEntry {
    let date: Date
    let current: Double
    let target: Double
}

struct HydrationProvider: TimelineProvider {
    func placeholder(in context: Context) -> HydrationEntry {
        HydrationEntry(date: .now, current: 1.8, target: 2.5)
    }

    func getSnapshot(in context: Context, completion: @escaping (HydrationEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HydrationEntry>) -> Void) {
        Task { @MainActor in
            let nutrition = AppGroupDataProvider.todayNutrition()
            let targets = AppGroupDataProvider.userTargets()
            let entry = HydrationEntry(
                date: .now,
                current: nutrition.water,
                target: targets.water
            )
            let nextUpdate = Calendar.current.date(
                byAdding: .minute, value: 15, to: .now
            ) ?? .now
            completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
        }
    }
}

struct HydrationWidgetView: View {
    let entry: HydrationEntry
    @Environment(\.widgetFamily) var family

    var progress: Double {
        guard entry.target > 0 else { return 0 }
        return min(1.0, entry.current / entry.target)
    }

    var body: some View {
        switch family {
        case .accessoryCircular:
            Gauge(value: progress) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 10))
            } currentValueLabel: {
                Text(String(format: "%.1f", entry.current))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
            }
            .gaugeStyle(.accessoryCircular)
            .tint(Color(red: 0.22, green: 0.74, blue: 0.97))
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text("Water")
                    .font(.system(size: 12, weight: .medium))
                Text(String(format: "%.1f/%.1fL", entry.current, entry.target))
                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
                ProgressView(value: progress)
                    .tint(Color(red: 0.22, green: 0.74, blue: 0.97))
            }
        default:
            VStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(red: 0.22, green: 0.74, blue: 0.97))
                    Text("Water")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Text(String(format: "%.1f", entry.current))
                    .font(.system(size: 36, weight: .light, design: .monospaced))
                Text(String(format: "of %.1fL", entry.target))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                ProgressView(value: progress)
                    .tint(Color(red: 0.22, green: 0.74, blue: 0.97))
                    .padding(.horizontal, 16)
            }
            .containerBackground(.fill.tertiary, for: .widget)
        }
    }
}

struct HydrationWidget: Widget {
    let kind = "HydrationWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HydrationProvider()) { entry in
            HydrationWidgetView(entry: entry)
        }
        .configurationDisplayName("Hydration Tracker")
        .description("Track your daily water intake")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .systemSmall])
    }
}
