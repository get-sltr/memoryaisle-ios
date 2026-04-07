import SwiftUI
import WidgetKit

struct HydrationEntry: TimelineEntry {
    let date: Date
    let current: Double
    let target: Double

    var progress: Double {
        target > 0 ? min(current / target, 1.0) : 0
    }

    static let placeholder = HydrationEntry(date: .now, current: 1.2, target: 2.5)
}

struct HydrationProvider: TimelineProvider {
    func placeholder(in context: Context) -> HydrationEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (HydrationEntry) -> Void) {
        completion(.placeholder)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HydrationEntry>) -> Void) {
        let entry = HydrationEntry(date: .now, current: 1.2, target: 2.5)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: .now)!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct HydrationWidgetView: View {
    let entry: HydrationEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .accessoryCircular:
            circularView
        default:
            smallView
        }
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Water")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(hex: 0x38BDF8))
                Spacer()
                Image(systemName: "drop.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Color(hex: 0x38BDF8).opacity(0.5))
            }

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(String(format: "%.1f", entry.current))
                    .font(.system(size: 32, weight: .medium, design: .monospaced))
                Text("/ \(String(format: "%.1f", entry.target))L")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(hex: 0x38BDF8).opacity(0.15))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(hex: 0x38BDF8))
                        .frame(width: geo.size.width * entry.progress)
                }
            }
            .frame(height: 4)
        }
        .padding(14)
        .containerBackground(for: .widget) {
            Color(hex: 0x0A0914)
        }
    }

    private var circularView: some View {
        Gauge(value: entry.progress) {
            Image(systemName: "drop.fill")
                .font(.system(size: 10))
        } currentValueLabel: {
            Text(String(format: "%.1f", entry.current))
                .font(.system(size: 12, weight: .medium, design: .monospaced))
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .tint(Color(hex: 0x38BDF8))
    }
}

struct HydrationWidget: Widget {
    let kind = "HydrationWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HydrationProvider()) { entry in
            HydrationWidgetView(entry: entry)
        }
        .configurationDisplayName("Hydration")
        .description("Track your daily water intake.")
        .supportedFamilies([.systemSmall, .accessoryCircular])
    }
}
