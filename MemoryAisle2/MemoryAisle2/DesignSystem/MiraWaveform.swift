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

    private var barWidth: CGFloat {
        switch size {
        case .hero: 5
        case .inline: 3
        case .compact: 2.5
        }
    }

    private var barGap: CGFloat {
        switch size {
        case .hero: 6
        case .inline: 3.5
        case .compact: 2.5
        }
    }

    private var maxBarHeight: CGFloat {
        switch size {
        case .hero: 44
        case .inline: 22
        case .compact: 14
        }
    }

    private var starSize: CGFloat {
        switch size {
        case .hero: 14
        case .inline: 8
        case .compact: 5
        }
    }

    private let heightRatios: [CGFloat] = [0.3, 0.68, 1.0, 0.58, 0.42]
    private let opacities: [Double] = [0.35, 0.7, 1.0, 0.6, 0.45]

    var body: some View {
        HStack(alignment: .center, spacing: barGap) {
            ForEach(0..<5, id: \.self) { i in
                capsule(at: i)
            }
            sparkle
        }
        .overlay(shimmer)
        .onAppear { startAnimation() }
        .onChange(of: state) { _, _ in startAnimation() }
    }

    // MARK: - Bar

    private func capsule(at index: Int) -> some View {
        let base = maxBarHeight * heightRatios[index]

        let height: CGFloat = switch state {
        case .idle:
            base * 0.3
        case .speaking:
            base * CGFloat(0.5 + 0.5 * sin(phase * .pi * 2 + Double(index) * 1.3))
        case .thinking:
            base * CGFloat(0.3 + 0.5 * sin(phase * .pi + Double(index) * 0.9))
        }

        let opacity: Double = switch state {
        case .idle:
            opacities[index] * 0.35
        case .speaking:
            opacities[index] * (0.7 + 0.3 * sin(phase * .pi * 2 + Double(index) * 0.8))
        case .thinking:
            opacities[index] * (0.35 + 0.5 * sin(phase * .pi + Double(index) * 0.6))
        }

        return Capsule()
            .fill(Color.white.opacity(opacity))
            .frame(width: barWidth, height: max(barWidth, height))
            .animation(
                .easeInOut(duration: 1.2 + Double(index) * 0.12)
                .repeatForever(autoreverses: true),
                value: phase
            )
    }

    // MARK: - Sparkle

    private var sparkle: some View {
        Image(systemName: "sparkle")
            .font(.system(size: starSize, weight: .heavy))
            .foregroundStyle(.white.opacity(state == .idle ? 0.4 : 0.95))
            .scaleEffect(state == .speaking
                ? CGFloat(0.85 + 0.15 * sin(phase * .pi * 3))
                : state == .thinking
                    ? CGFloat(0.7 + 0.3 * sin(phase * .pi * 2))
                    : 0.8
            )
            .animation(
                .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                value: phase
            )
    }

    // MARK: - Shimmer

    private var shimmer: some View {
        GeometryReader { geo in
            LinearGradient(
                colors: [
                    .clear,
                    .white.opacity(state == .speaking ? 0.2 : 0.05),
                    .clear
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: geo.size.width * 0.4)
            .offset(x: shimmerOffset * geo.size.width)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 2.4)
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
                .easeInOut(duration: 1.2)
                .repeatForever(autoreverses: true)
            ) {
                phase = 1
            }
        }
    }
}
