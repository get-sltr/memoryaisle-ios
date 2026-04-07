import SwiftUI
import WidgetKit

struct ProteinEntry: TimelineEntry {
    let date: Date
    let current: Int
    let target: Int

    var progress: Double {
        target > 0 ? min(Double(current) / Double(target), 1.0) : 0
    }

    var deficit: Int {
        max(0, target - current)
    }

    static let placeholder = ProteinEntry(date: .now, current: 82, target: 140)
}

struct ProteinProvider: TimelineProvider {
    func placeholder(in context: Context) -> ProteinEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (ProteinEntry) -> Void) {
        completion(.placeholder)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ProteinEntry>) -> Void) {
        // In production: read from shared App Group UserDefaults
        let entry = ProteinEntry(date: .now, current: 82, target: 140)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: .now)!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct ProteinWidgetView: View {
    let entry: ProteinEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .accessoryCircular:
            circularView
        case .accessoryRectangular:
            rectangularView
        default:
            smallView
        }
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Protein")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(hex: 0xA78BFA))
                Spacer()
                if entry.deficit > 0 {
                    Text("\(entry.deficit)g left")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(entry.current)")
                    .font(.system(size: 32, weight: .medium, design: .monospaced))
                Text("/ \(entry.target)g")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(hex: 0xA78BFA).opacity(0.15))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(hex: 0xA78BFA))
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
            Text("P")
                .font(.system(size: 12, weight: .bold))
        } currentValueLabel: {
            Text("\(entry.current)")
                .font(.system(size: 14, weight: .medium, design: .monospaced))
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .tint(Color(hex: 0xA78BFA))
    }

    private var rectangularView: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Protein")
                    .font(.system(size: 12, weight: .medium))
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text("\(entry.current)")
                        .font(.system(size: 20, weight: .medium, design: .monospaced))
                    Text("/\(entry.target)g")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Gauge(value: entry.progress) {}
                .gaugeStyle(.accessoryLinearCapacity)
                .tint(Color(hex: 0xA78BFA))
                .frame(width: 50)
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
        .description("Track your daily protein intake.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}
