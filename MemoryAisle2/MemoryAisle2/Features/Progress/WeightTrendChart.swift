import Charts
import SwiftUI

struct WeightTrendChart: View {
    @Environment(\.colorScheme) private var scheme
    let data: [(date: Date, value: Double)]

    private var minWeight: Double {
        (data.map(\.value).min() ?? 0) - 2
    }

    private var maxWeight: Double {
        (data.map(\.value).max() ?? 0) + 2
    }

    private var weightChange: Double {
        guard let first = data.first?.value, let last = data.last?.value else { return 0 }
        return last - first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("WEIGHT TREND")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Theme.Text.tertiary(for: scheme))
                    .tracking(1.2)

                Spacer()

                if !data.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: weightChange <= 0 ? "arrow.down.right" : "arrow.up.right")
                            .font(.system(size: 10))
                        Text(String(format: "%+.1f lbs", weightChange))
                            .font(.system(size: 12, design: .monospaced))
                    }
                    .foregroundStyle(weightChange <= 0
                        ? Theme.Semantic.onTrack(for: scheme)
                        : Theme.Semantic.fiber(for: scheme)
                    )
                }
            }

            if data.isEmpty {
                emptyState
            } else {
                chart
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.Surface.glass(for: scheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Theme.Border.glass(for: scheme), lineWidth: Theme.glassBorderWidth)
        )
    }

    private var chart: some View {
        Chart {
            ForEach(Array(data.enumerated()), id: \.offset) { _, point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Weight", point.value)
                )
                .foregroundStyle(Color.violet)
                .lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(.catmullRom)

                AreaMark(
                    x: .value("Date", point.date),
                    y: .value("Weight", point.value)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.violet.opacity(0.15), Color.violet.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
            }
        }
        .chartYScale(domain: minWeight...maxWeight)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    .foregroundStyle(Theme.Text.tertiary(for: scheme))
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { _ in
                AxisValueLabel()
                    .foregroundStyle(Theme.Text.tertiary(for: scheme))
                AxisGridLine()
                    .foregroundStyle(Theme.Border.glass(for: scheme))
            }
        }
        .frame(height: 160)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "heart.fill")
                .font(.system(size: 20))
                .foregroundStyle(Theme.Semantic.warning(for: scheme).opacity(0.3))

            Text("Connect HealthKit to see your trend")
                .font(.system(size: 13))
                .foregroundStyle(Theme.Text.tertiary(for: scheme))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
    }
}
