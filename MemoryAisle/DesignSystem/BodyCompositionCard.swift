import SwiftUI

struct BodyCompositionCard: View {
    @Environment(\.colorScheme) private var scheme

    let leanMassLbs: Double
    let bodyFatPercent: Double
    let leanMassDelta: Double
    let bodyFatDelta: Double
    let weightHistory: [Double]
    let leanMassHistory: [Double]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Text("BODY COMPOSITION")
                    .font(Typography.micro)
                    .letterSpaced(0.8)
                    .foregroundStyle(Theme.Text.tertiary(for: scheme))

                HStack(spacing: Theme.Spacing.lg) {
                    statColumn(
                        value: String(format: "%.1f", leanMassLbs),
                        unit: "lbs",
                        label: "LEAN MASS",
                        delta: leanMassDelta
                    )

                    statColumn(
                        value: String(format: "%.1f", bodyFatPercent),
                        unit: "%",
                        label: "BODY FAT",
                        delta: bodyFatDelta
                    )

                    Spacer()

                    miniSparkline
                        .frame(width: 80, height: 36)
                }
            }
            .padding(Theme.Spacing.cardPad)
        }
    }

    private func statColumn(
        value: String,
        unit: String,
        label: String,
        delta: Double
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(Typography.dataSmall)
                    .tabularFigures()
                    .foregroundStyle(Theme.Text.primary)
                Text(unit)
                    .font(Typography.caption)
                    .foregroundStyle(Theme.Text.tertiary(for: scheme))
            }

            Text(label)
                .font(Typography.micro)
                .letterSpaced(0.8)
                .foregroundStyle(Theme.Text.hint(for: scheme))

            if delta != 0 {
                Text(delta > 0 ? "+\(String(format: "%.1f", delta))" : String(format: "%.1f", delta))
                    .font(Typography.caption)
                    .foregroundStyle(
                        delta > 0
                            ? Theme.Semantic.onTrack(for: scheme)
                            : Theme.Semantic.warning(for: scheme)
                    )
            }
        }
    }

    private var miniSparkline: some View {
        Canvas { context, size in
            guard weightHistory.count > 1 else { return }

            drawLine(
                context: context,
                size: size,
                points: weightHistory,
                color: Color.violet,
                lineWidth: 1.5
            )

            if leanMassHistory.count > 1 {
                drawLine(
                    context: context,
                    size: size,
                    points: leanMassHistory,
                    color: Color(hex: 0x34D399),
                    lineWidth: 1.0
                )
            }
        }
    }

    private func drawLine(
        context: GraphicsContext,
        size: CGSize,
        points: [Double],
        color: Color,
        lineWidth: CGFloat
    ) {
        let allPoints = weightHistory + leanMassHistory
        guard let minVal = allPoints.min(),
              let maxVal = allPoints.max(),
              maxVal > minVal else { return }

        let path = Path { p in
            for (i, val) in points.enumerated() {
                let x = size.width * CGFloat(i) / CGFloat(points.count - 1)
                let y = size.height * (1 - CGFloat((val - minVal) / (maxVal - minVal)))
                if i == 0 {
                    p.move(to: CGPoint(x: x, y: y))
                } else {
                    p.addLine(to: CGPoint(x: x, y: y))
                }
            }
        }

        context.stroke(
            path,
            with: .color(color),
            lineWidth: lineWidth
        )
    }
}
