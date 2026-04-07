import SwiftUI

struct MiraIntroScreen: View {
    let onContinue: () -> Void
    @State private var miraState: MiraState = .idle
    @State private var showGreeting = false
    @State private var showSubtitle = false
    @State private var showButton = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            Spacer()

            // Mira waveform - generous space around it
            MiraWaveform(state: miraState, size: .hero)
                .frame(height: 60)
                .padding(.bottom, 48)

            // Greeting
            Text("Hello. I'm Mira.")
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(.white)
                .opacity(showGreeting ? 1 : 0)
                .offset(y: showGreeting ? 0 : 16)

            Text("Your personal nutrition companion\nfor this journey.")
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.top, 14)
                .opacity(showSubtitle ? 1 : 0)
                .offset(y: showSubtitle ? 0 : 12)

            Spacer()
            Spacer()
            Spacer()

            // CTA
            VStack(spacing: 16) {
                VioletButton("Let's get started") {
                    onContinue()
                }
                .padding(.horizontal, 32)

                Text("Takes about 2 minutes")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.white.opacity(0.25))
            }
            .opacity(showButton ? 1 : 0)
            .padding(.bottom, 56)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.4)) {
                miraState = .speaking
            }
            withAnimation(.easeOut(duration: 0.7).delay(0.9)) {
                showGreeting = true
            }
            withAnimation(.easeOut(duration: 0.7).delay(1.4)) {
                showSubtitle = true
            }
            withAnimation(.easeOut(duration: 0.6).delay(2.0)) {
                showButton = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                withAnimation(.easeOut(duration: 0.6)) {
                    miraState = .idle
                }
            }
        }
    }
}
