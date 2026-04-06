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

    var scale: CGFloat {
        switch self {
        case .hero: 1.0
        case .inline: 0.65
        case .compact: 0.45
        }
    }
}

struct MiraWaveform: View {
    let state: MiraState
    let size: MiraSize

    // Bar specs (hero scale): heights, opacities
    private static let barHeights: [CGFloat] = [10, 22, 32, 18, 14]
    private static let barOpacities: [Double] = [0.35, 0.8, 1.0, 0.7, 0.5]
    private static let barWidth: CGFloat = 3.5
    private static let barGap: CGFloat = 4
    private static let starSize: CGFloat = 10

    @State private var animationPhase: Double = 0

    var body: some View {
        HStack(alignment: .center, spacing: Self.barGap * size.scale) {
            ForEach(0..<5, id: \.self) { index in
                bar(at: index)
            }

            star
        }
        .onAppear {
            guard state != .idle else { return }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                animationPhase = 1
            }
        }
        .onChange(of: state) { _, newState in
            if newState == .idle {
                withAnimation(Theme.Motion.gentle) {
                    animationPhase = 0
                }
            } else {
                withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                    animationPhase = 1
                }
            }
        }
    }

    // MARK: - Bar

    @ViewBuilder
    private func bar(at index: Int) -> some View {
        let baseHeight = Self.barHeights[index] * size.scale
        let baseOpacity = Self.barOpacities[index]

        let height: CGFloat = switch state {
        case .speaking:
            baseHeight * (0.85 + 0.3 * sin(animationPhase * .pi * 2 + Double(index) * 0.8))
        case .idle:
            baseHeight * 0.4
        case .thinking:
            baseHeight * (0.4 + 0.6 * sin(animationPhase * .pi + Double(index) * 0.6))
        }

        let opacity: Double = switch state {
        case .speaking:
            baseOpacity
        case .idle:
            baseOpacity * 0.5
        case .thinking:
            baseOpacity * (0.5 + 0.5 * sin(animationPhase * .pi + Double(index) * 0.5))
        }

        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(Color.white.opacity(opacity))
            .frame(
                width: Self.barWidth * size.scale,
                height: height
            )
            .animation(
                .easeInOut(duration: 1.8 + Double(index) * 0.1)
                .repeatForever(autoreverses: true)
                .delay(Double(index) * 0.08),
                value: animationPhase
            )
    }

    // MARK: - Star

    private var star: some View {
        let starScale = Self.starSize * size.scale

        return FourPointStar()
            .fill(Color.white)
            .frame(width: starScale, height: starScale)
            .offset(y: -8 * size.scale)
            .opacity(state == .idle ? 0.6 : 1.0)
            .scaleEffect(state == .thinking
                ? 0.8 + 0.4 * sin(animationPhase * .pi * 2)
                : 1.0
            )
            .animation(
                .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                value: animationPhase
            )
    }
}

// MARK: - Four-Point Star Shape

struct FourPointStar: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let w = rect.width / 2
        let h = rect.height / 2
        let inner: CGFloat = 0.25

        var path = Path()
        path.move(to: CGPoint(x: center.x, y: center.y - h))
        path.addLine(to: CGPoint(x: center.x + w * inner, y: center.y - h * inner))
        path.addLine(to: CGPoint(x: center.x + w, y: center.y))
        path.addLine(to: CGPoint(x: center.x + w * inner, y: center.y + h * inner))
        path.addLine(to: CGPoint(x: center.x, y: center.y + h))
        path.addLine(to: CGPoint(x: center.x - w * inner, y: center.y + h * inner))
        path.addLine(to: CGPoint(x: center.x - w, y: center.y))
        path.addLine(to: CGPoint(x: center.x - w * inner, y: center.y - h * inner))
        path.closeSubpath()
        return path
    }
}

// MARK: - Preview Support

#if DEBUG
#Preview("Mira States") {
    ZStack {
        Color.indigoBlack.ignoresSafeArea()

        VStack(spacing: 48) {
            VStack(spacing: 8) {
                Text("Speaking - Hero")
                    .font(Typography.caption)
                    .foregroundStyle(.white.opacity(0.5))
                MiraWaveform(state: .speaking, size: .hero)
            }

            VStack(spacing: 8) {
                Text("Thinking - Inline")
                    .font(Typography.caption)
                    .foregroundStyle(.white.opacity(0.5))
                MiraWaveform(state: .thinking, size: .inline)
            }

            VStack(spacing: 8) {
                Text("Idle - Compact")
                    .font(Typography.caption)
                    .foregroundStyle(.white.opacity(0.5))
                MiraWaveform(state: .idle, size: .compact)
            }
        }
    }
}
#endif
