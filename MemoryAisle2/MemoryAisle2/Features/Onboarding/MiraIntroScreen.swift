import SwiftUI

struct MiraIntroScreen: View {
    let onContinue: () -> Void
    @State private var miraState: MiraState = .idle
    @State private var showGreeting = false
    @State private var showSubtitle = false
    @State private var showButton = false

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                // Top breathing space
                Spacer()
                    .frame(height: geo.size.height * 0.28)

                // Mira waveform
                MiraWaveform(state: miraState, size: .hero)
                    .frame(height: 70)

                Spacer()
                    .frame(height: 52)

                // Greeting
                Text("Hello. I'm Mira.")
                    .font(.system(size: 34, weight: .light, design: .serif))
                    .foregroundStyle(.white)
                    .tracking(0.5)
                    .opacity(showGreeting ? 1 : 0)
                    .offset(y: showGreeting ? 0 : 20)

                Spacer()
                    .frame(height: 16)

                // Subtitle
                Text("Your personal nutrition companion\nfor this journey.")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(.white.opacity(0.45))
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .opacity(showSubtitle ? 1 : 0)
                    .offset(y: showSubtitle ? 0 : 14)

                Spacer()

                // CTA - transparent glass with purple glow
                VStack(spacing: 18) {
                    GlowButton("Let's get started") {
                        HapticManager.medium()
                        onContinue()
                    }

                    Text("Takes about 2 minutes")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.white.opacity(0.2))
                }
                .padding(.horizontal, 32)
                .opacity(showButton ? 1 : 0)
                .offset(y: showButton ? 0 : 10)

                Spacer()
                    .frame(height: 50)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.5)) {
                miraState = .speaking
            }
            withAnimation(.easeOut(duration: 0.8).delay(1.0)) {
                showGreeting = true
            }
            withAnimation(.easeOut(duration: 0.8).delay(1.6)) {
                showSubtitle = true
            }
            withAnimation(.easeOut(duration: 0.7).delay(2.3)) {
                showButton = true
            }
        }
    }
}
