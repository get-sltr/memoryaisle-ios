import SwiftUI
import WidgetKit

struct ProteinEntry: TimelineEntry {
    let date: Date
    let current: Double
    let target: Int
}

struct ProteinProvider: TimelineProvider {
    func placeholder(in context: Context) -> ProteinEntry {
        ProteinEntry(date: .now, current: 85, target: 140)
    }

    func getSnapshot(in context: Context, completion: @escaping (ProteinEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ProteinEntry>) -> Void) {
        Task { @MainActor in
            let nutrition = AppGroupDataProvider.todayNutrition()
            let targets = AppGroupDataProvider.userTargets()
            let entry = ProteinEntry(
                date: .now,
                current: nutrition.protein,
                target: targets.protein
            )
            let nextUpdate = Calendar.current.date(
                byAdding: .minute, value: 15, to: .now
            ) ?? .now
            completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
        }
    }
}

struct ProteinWidgetView: View {
    let entry: ProteinEntry
    @Environment(\.widgetFamily) var family

    var progress: Double {
        guard entry.target > 0 else { return 0 }
        return min(1.0, entry.current / Double(entry.target))
    }

    var body: some View {
        switch family {
        case .accessoryCircular:
            Gauge(value: progress) {
                Text("P")
                    .font(.system(size: 12, weight: .bold))
            } currentValueLabel: {
                Text("\(Int(entry.current))")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
            }
            .gaugeStyle(.accessoryCircular)
            .tint(Color(red: 0.655, green: 0.545, blue: 0.98))
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text("Protein")
                    .font(.system(size: 12, weight: .medium))
                Text("\(Int(entry.current))/\(entry.target)g")
                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
                ProgressView(value: progress)
                    .tint(Color(red: 0.655, green: 0.545, blue: 0.98))
            }
        default:
            VStack(spacing: 8) {
                Text("Protein")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("\(Int(entry.current))")
                    .font(.system(size: 36, weight: .light, design: .monospaced))
                Text("of \(entry.target)g")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                ProgressView(value: progress)
                    .tint(Color(red: 0.655, green: 0.545, blue: 0.98))
                    .padding(.horizontal, 16)
            }
            .containerBackground(.fill.tertiary, for: .widget)
        }
    }
}

struct ProteinWidget: Widget {
    let kind = "ProteinWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ProteinProvider()) { entry in
            ProteinWidgetView(entry: entry)
        }
        .configurationDisplayName("Protein Tracker")
        .description("Track your daily protein intake")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .systemSmall])
    }
}
