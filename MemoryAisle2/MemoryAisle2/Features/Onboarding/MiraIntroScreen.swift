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
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(.white)
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
                    Button(action: {
                        HapticManager.medium()
                        onContinue()
                    }) {
                        Text("Let's get started")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(.ultraThinMaterial.opacity(0.6))
                            )
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.violet.opacity(0.12))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.violet.opacity(0.3), lineWidth: 0.5)
                            )
                            .shadow(color: Color.violet.opacity(0.25), radius: 20, y: 4)
                            .shadow(color: Color.violet.opacity(0.1), radius: 40, y: 8)
                    }
                    .buttonStyle(GlassPressStyle())

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
