import SwiftUI

struct VoiceWaveform: View {
    let isActive: Bool
    let barCount: Int

    @State private var animationPhase: Double = 0

    init(isActive: Bool, barCount: Int = 24) {
        self.isActive = isActive
        self.barCount = barCount
    }

    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(0..<barCount, id: \.self) { index in
                bar(at: index)
            }
        }
        .frame(height: 32)
        .onAppear {
            guard isActive else { return }
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                animationPhase = 1
            }
        }
        .onChange(of: isActive) { _, active in
            if active {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    animationPhase = 1
                }
            } else {
                withAnimation(Theme.Motion.gentle) {
                    animationPhase = 0
                }
            }
        }
    }

    @ViewBuilder
    private func bar(at index: Int) -> some View {
        let normalized = Double(index) / Double(barCount - 1)
        let centerDistance = abs(normalized - 0.5) * 2
        let maxHeight: CGFloat = 28 * (1 - centerDistance * 0.6)

        let height: CGFloat = if isActive {
            maxHeight * CGFloat(0.3 + 0.7 * sin(animationPhase * .pi + Double(index) * 0.4))
        } else {
            3
        }

        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
            .fill(Color.violet.opacity(isActive ? 0.6 + 0.4 * (1 - centerDistance) : 0.2))
            .frame(width: 2, height: max(3, height))
            .animation(
                .easeInOut(duration: 0.6 + Double(index) * 0.02)
                .repeatForever(autoreverses: true)
                .delay(Double(index) * 0.03),
                value: animationPhase
            )
    }
}

#if DEBUG
#Preview("Voice Waveform") {
    ZStack {
        Color.indigoBlack.ignoresSafeArea()

        VStack(spacing: 32) {
            VoiceWaveform(isActive: true)
            VoiceWaveform(isActive: false)
        }
        .padding()
    }
}
#endif
