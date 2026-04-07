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
    @State private var shimmerOffset: CGFloat = -1

    // 7 elements: symmetric arc (small -> tall -> small)
    // Heights as ratios: dot, short, medium, tall, medium, short, dot
    private let heightRatios: [CGFloat] = [0.15, 0.35, 0.65, 1.0, 0.65, 0.35, 0.15]
    private let opacities: [Double] = [0.35, 0.5, 0.7, 1.0, 0.7, 0.5, 0.35]

    private var dotSize: CGFloat {
        switch size {
        case .hero: 5
        case .inline: 3.5
        case .compact: 2.5
        }
    }

    private var gap: CGFloat {
        switch size {
        case .hero: 5
        case .inline: 3.5
        case .compact: 2.5
        }
    }

    private var maxHeight: CGFloat {
        switch size {
        case .hero: 40
        case .inline: 22
        case .compact: 14
        }
    }

    private var starSize: CGFloat {
        switch size {
        case .hero: 16
        case .inline: 10
        case .compact: 7
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: gap) {
            ForEach(0..<7, id: \.self) { i in
                dot(at: i)
            }
            sparkle
        }
        .overlay(shimmer)
        .onAppear { startAnimation() }
        .onChange(of: state) { _, _ in startAnimation() }
    }

    // MARK: - Dot/Bar

    private func dot(at index: Int) -> some View {
        let baseHeight = maxHeight * heightRatios[index]

        let height: CGFloat = switch state {
        case .idle:
            max(dotSize, baseHeight * 0.2)
        case .speaking:
            max(dotSize, baseHeight * CGFloat(0.4 + 0.6 * sin(phase * .pi * 2 + Double(index) * 0.9)))
        case .thinking:
            max(dotSize, baseHeight * CGFloat(0.2 + 0.5 * sin(phase * .pi + Double(index) * 0.7)))
        }

        let opacity: Double = switch state {
        case .idle:
            opacities[index] * 0.3
        case .speaking:
            opacities[index] * (0.5 + 0.5 * sin(phase * .pi * 2 + Double(index) * 0.6))
        case .thinking:
            opacities[index] * (0.3 + 0.5 * sin(phase * .pi + Double(index) * 0.5))
        }

        return Capsule()
            .fill(Color.white.opacity(opacity))
            .frame(width: dotSize, height: height)
            .animation(
                .easeInOut(duration: 1.3 + Double(index) * 0.1)
                .repeatForever(autoreverses: true),
                value: phase
            )
    }

    // MARK: - Sparkle

    private var sparkle: some View {
        Image(systemName: "sparkle")
            .font(.system(size: starSize, weight: .semibold))
            .foregroundStyle(.white.opacity(state == .idle ? 0.3 : 0.85))
            .scaleEffect(state == .speaking
                ? CGFloat(0.85 + 0.15 * sin(phase * .pi * 3))
                : state == .thinking
                    ? CGFloat(0.7 + 0.3 * sin(phase * .pi * 2))
                    : 0.8
            )
            .animation(
                .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                value: phase
            )
    }

    // MARK: - Shimmer

    private var shimmer: some View {
        GeometryReader { geo in
            LinearGradient(
                colors: [
                    .clear,
                    .white.opacity(state == .speaking ? 0.15 : 0.03),
                    .clear
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: geo.size.width * 0.35)
            .offset(x: shimmerOffset * geo.size.width)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 2.8)
                    .repeatForever(autoreverses: false)
                ) {
                    shimmerOffset = 1.4
                }
            }
        }
        .allowsHitTesting(false)
        .clipShape(Rectangle())
    }

    // MARK: - Animation

    private func startAnimation() {
        if state == .idle {
            withAnimation(.easeOut(duration: 0.5)) { phase = 0 }
        } else {
            withAnimation(
                .easeInOut(duration: 1.3)
                .repeatForever(autoreverses: true)
            ) {
                phase = 1
            }
        }
    }
}
