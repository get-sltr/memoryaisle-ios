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

struct MiraWaveform: View {
    let state: MiraState
    let size: MiraSize

    @State private var phase: Double = 0

    private var barWidth: CGFloat {
        switch size {
        case .hero: 4
        case .inline: 3
        case .compact: 2.5
        }
    }

    private var barGap: CGFloat {
        switch size {
        case .hero: 5
        case .inline: 3.5
        case .compact: 2.5
        }
    }

    private var maxBarHeight: CGFloat {
        switch size {
        case .hero: 36
        case .inline: 20
        case .compact: 14
        }
    }

    private var starSize: CGFloat {
        switch size {
        case .hero: 12
        case .inline: 7
        case .compact: 5
        }
    }

    private let heightRatios: [CGFloat] = [0.3, 0.7, 1.0, 0.55, 0.4]
    private let opacities: [Double] = [0.4, 0.75, 1.0, 0.65, 0.5]

    var body: some View {
        HStack(alignment: .center, spacing: barGap) {
            ForEach(0..<5, id: \.self) { i in
                capsule(at: i)
            }
            star
        }
        .onAppear { startAnimation() }
        .onChange(of: state) { _, _ in startAnimation() }
    }

    private func capsule(at index: Int) -> some View {
        let base = maxBarHeight * heightRatios[index]

        let height: CGFloat = switch state {
        case .idle:
            base * 0.35
        case .speaking:
            base * CGFloat(0.6 + 0.4 * sin(phase * .pi * 2 + Double(index) * 1.2))
        case .thinking:
            base * CGFloat(0.35 + 0.5 * sin(phase * .pi + Double(index) * 0.8))
        }

        let opacity: Double = switch state {
        case .idle:
            opacities[index] * 0.4
        case .speaking:
            opacities[index]
        case .thinking:
            opacities[index] * (0.4 + 0.6 * sin(phase * .pi + Double(index) * 0.6))
        }

        return Capsule()
            .fill(Color.white.opacity(opacity))
            .frame(width: barWidth, height: max(barWidth, height))
            .animation(
                .easeInOut(duration: 1.6 + Double(index) * 0.15)
                .repeatForever(autoreverses: true),
                value: phase
            )
    }

    private var star: some View {
        Image(systemName: "sparkle")
            .font(.system(size: starSize, weight: .bold))
            .foregroundStyle(Color.white.opacity(state == .idle ? 0.5 : 0.9))
            .scaleEffect(state == .thinking ? CGFloat(0.7 + 0.3 * sin(phase * .pi * 2)) : 1.0)
            .animation(
                .easeInOut(duration: 1.4).repeatForever(autoreverses: true),
                value: phase
            )
    }

    private func startAnimation() {
        if state == .idle {
            withAnimation(.easeOut(duration: 0.4)) { phase = 0 }
        } else {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                phase = 1
            }
        }
    }
}
