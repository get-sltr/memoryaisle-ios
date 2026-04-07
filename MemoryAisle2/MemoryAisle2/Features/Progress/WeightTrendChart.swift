import Charts
import SwiftUI

struct WeightTrendChart: View {
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
                    .foregroundStyle(.white.opacity(0.25))
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
                        ? Color(hex: 0x34D399)
                        : Color(hex: 0xFBBF24)
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
                .fill(.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.white.opacity(0.06), lineWidth: 0.5)
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
                    .foregroundStyle(.white.opacity(0.2))
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { _ in
                AxisValueLabel()
                    .foregroundStyle(.white.opacity(0.2))
                AxisGridLine()
                    .foregroundStyle(.white.opacity(0.04))
            }
        }
        .frame(height: 160)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "heart.fill")
                .font(.system(size: 20))
                .foregroundStyle(Color(hex: 0xF87171).opacity(0.3))

            Text("Connect HealthKit to see your trend")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.3))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
    }
}
