import SwiftUI

struct MiraIntroScreen: View {
    let onContinue: () -> Void
    @State private var miraState: MiraState = .idle
    @State private var showText = false
    @State private var showButton = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Mira waveform hero
            MiraWaveform(state: miraState, size: .hero)
                .padding(.bottom, Theme.Spacing.xxl)

            // Greeting text
            VStack(spacing: Theme.Spacing.md) {
                Text("Hello. I'm Mira.")
                    .font(Typography.displayMedium)
                    .foregroundStyle(.white)

                Text("Your personal nutrition companion\nfor this journey.")
                    .font(Typography.bodyLarge)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
            .opacity(showText ? 1 : 0)
            .offset(y: showText ? 0 : 20)

            Spacer()

            // CTA
            VStack(spacing: Theme.Spacing.md) {
                VioletButton("Let's get started") {
                    onContinue()
                }

                Text("Tap to speak, or just listen")
                    .font(Typography.caption)
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.xxl)
            .opacity(showButton ? 1 : 0)
            .offset(y: showButton ? 0 : 10)
        }
        .onAppear {
            // Staggered entrance
            withAnimation(Theme.Motion.gentle.delay(0.3)) {
                miraState = .speaking
            }
            withAnimation(Theme.Motion.gentle.delay(0.8)) {
                showText = true
            }
            withAnimation(Theme.Motion.gentle.delay(1.4)) {
                showButton = true
            }
            // Settle to idle
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation(Theme.Motion.gentle) {
                    miraState = .idle
                }
            }
        }
    }
}
