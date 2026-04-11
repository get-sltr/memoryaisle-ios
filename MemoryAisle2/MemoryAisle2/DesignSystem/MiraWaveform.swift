import SwiftUI

enum MiraState {
    case speaking
    case idle
    case thinking
}

enum MiraSize {
    case hero
    case inline
    case compact
}

// Mira's signature avatar: 5 vertical bars + 1 four-point star.
// Shape reads as three tall bars, two dots, and the star — "|||..*".
// Idle is fully static (no CPU cost). Thinking/speaking are driven by
// TimelineView(.animation) which pauses automatically when idle.
struct MiraWaveform: View {
    let state: MiraState
    let size: MiraSize

    // Asymmetric ratios — tall tall tall dot dot — so the waveform
    // always has visible character even when idle.
    private let heightRatios: [CGFloat] = [1.0, 0.85, 0.7, 0.25, 0.25]
    private let baseOpacities: [Double] = [1.0, 0.9, 0.8, 0.55, 0.55]

    private var barWidth: CGFloat {
        switch size {
        case .hero: 5
        case .inline: 3.5
        case .compact: 2.5
        }
    }

    private var gap: CGFloat {
        switch size {
        case .hero: 6
        case .inline: 4
        case .compact: 3
        }
    }

    private var maxHeight: CGFloat {
        switch size {
        case .hero: 50
        case .inline: 28
        case .compact: 16
        }
    }

    private var starSize: CGFloat {
        switch size {
        case .hero: 18
        case .inline: 11
        case .compact: 8
        }
    }

    var body: some View {
        TimelineView(
            .animation(minimumInterval: 1.0 / 30.0, paused: state == .idle)
        ) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let phase = t.truncatingRemainder(dividingBy: 2.4) / 2.4

            HStack(alignment: .center, spacing: gap) {
                ForEach(0..<5, id: \.self) { i in
                    bar(at: i, phase: phase)
                }
                sparkle(phase: phase)
            }
        }
    }

    // MARK: - Bars

    private func bar(at index: Int, phase: Double) -> some View {
        let baseHeight = maxHeight * heightRatios[index]
        let baseOpacity = baseOpacities[index]

        let height: CGFloat
        let opacity: Double

        switch state {
        case .idle:
            height = max(barWidth, baseHeight)
            opacity = baseOpacity
        case .thinking:
            let wave = 0.5 + 0.5 * sin(phase * .pi * 2 + Double(index) * 0.9)
            height = max(barWidth, baseHeight * CGFloat(0.55 + 0.45 * wave))
            opacity = baseOpacity * (0.6 + 0.4 * wave)
        case .speaking:
            let wave = 0.5 + 0.5 * sin(phase * .pi * 4 + Double(index) * 0.7)
            height = max(barWidth, baseHeight * CGFloat(0.45 + 0.55 * wave))
            opacity = baseOpacity * (0.7 + 0.3 * wave)
        }

        return Capsule()
            .fill(Color.white.opacity(opacity))
            .frame(width: barWidth, height: height)
    }

    // MARK: - Star

    private func sparkle(phase: Double) -> some View {
        let scale: CGFloat = switch state {
        case .idle:
            1.0
        case .thinking:
            CGFloat(0.85 + 0.15 * sin(phase * .pi * 2))
        case .speaking:
            CGFloat(0.9 + 0.15 * sin(phase * .pi * 3))
        }

        return Image(systemName: "sparkle")
            .font(.system(size: starSize, weight: .semibold))
            .foregroundStyle(.white.opacity(state == .idle ? 0.85 : 1.0))
            .scaleEffect(scale)
    }
}
