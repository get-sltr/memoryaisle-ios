import SwiftUI

/// Five-bar Canvas that animates per `MiraVoiceState`:
///   - .idle      → gentle individual breathing per bar
///   - .listening → reacts to mic amplitude (0...1) with per-bar jitter
///   - .thinking  → soft sequential pulse traveling left to right
///   - .speaking  → multi-frequency speech-wave envelope
///   - .checkIn   → bigger, slower breath to draw attention without urgency
///
/// 30fps timeline matches `FirefliesLayer` and `MiraWaveform` so the editorial
/// canvas has a single perceptual cadence.
struct MiraBars: View {
    let state: MiraVoiceState
    /// Live RMS-smoothed mic level, 0...1. Only consumed in `.listening` —
    /// other states ignore this and run their own deterministic envelopes.
    let amplitude: CGFloat

    private let barCount = 5

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            Canvas { context, size in
                let barWidth: CGFloat = 6
                let gap: CGFloat = 6
                let totalWidth = CGFloat(barCount) * barWidth + CGFloat(barCount - 1) * gap
                let startX = (size.width - totalWidth) / 2

                let now = timeline.date.timeIntervalSinceReferenceDate

                for index in 0..<barCount {
                    let x = startX + CGFloat(index) * (barWidth + gap)
                    let height = barHeight(for: index, at: now, in: size)
                    let y = (size.height - height) / 2
                    let rect = CGRect(x: x, y: y, width: barWidth, height: height)
                    let path = Path(roundedRect: rect, cornerRadius: barWidth / 2)
                    context.fill(path, with: .color(.white))
                }
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: - Per-state envelope

    private func barHeight(for index: Int, at time: TimeInterval, in size: CGSize) -> CGFloat {
        let maxHeight: CGFloat = 64
        let minHeight: CGFloat = 14

        switch state {
        case .idle:
            let baseHeights: [CGFloat] = [25, 41, 59, 39, 21]
            let speeds: [Double] = [3.0, 3.4, 2.8, 3.2, 3.6]
            let phases: [Double] = [0, 0.2, 0.4, 0.1, 0.3]
            let pulse = sin(time * (2 * .pi / speeds[index]) + phases[index] * 2 * .pi)
            return baseHeights[index] + CGFloat(pulse) * 4

        case .listening:
            let baseHeights: [CGFloat] = [0.42, 0.68, 0.88, 0.66, 0.40]
            let jitter = sin(time * 8.0 + Double(index) * 0.6) * 0.10 + 1.0
            let h = maxHeight * baseHeights[index] * (0.4 + amplitude * 1.2) * CGFloat(jitter)
            return Swift.max(minHeight, Swift.min(maxHeight, h))

        case .thinking:
            // Light pulse traveling left to right across the bars.
            let cycleTime = 1.6
            let phase = (time.truncatingRemainder(dividingBy: cycleTime)) / cycleTime
            let position = phase * Double(barCount + 2) - 1.0
            let distance = abs(Double(index) - position)
            let intensity = Swift.max(0, 1.0 - distance * 0.7)
            return minHeight + CGFloat(intensity) * 38

        case .speaking:
            let primary = sin(time * 6.5 + Double(index) * 0.8)
            let secondary = sin(time * 11.0 + Double(index) * 1.3) * 0.5
            let tertiary = sin(time * 3.2 + Double(index) * 0.4) * 0.7
            let combined = (primary + secondary + tertiary) / 2.2
            let normalized = (combined + 1.0) / 2.0
            let baseHeights: [CGFloat] = [0.45, 0.70, 0.95, 0.65, 0.40]
            return Swift.max(minHeight, maxHeight * baseHeights[index] * (0.5 + CGFloat(normalized) * 0.7))

        case .checkIn:
            let baseHeights: [CGFloat] = [32, 48, 62, 46, 30]
            let pulse = sin(time * 1.4 + Double(index) * 0.3)
            return baseHeights[index] + CGFloat(pulse) * 8
        }
    }
}
