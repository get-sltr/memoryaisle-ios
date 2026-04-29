import SwiftUI

/// Screen 1 of 6 — Welcome / first launch.
///
/// First-run-only gate: the auth router checks `ma_seen_welcome` and skips
/// straight to Sign In on subsequent cold launches. The screen itself is
/// stateless; tapping ENTER fires `onEnter` and the router records the
/// user-defaults flag + pushes the next route.
///
/// The italic two-line question is the brand opener. The leading em dash
/// in `— A QUESTION TO BEGIN WITH` is the sanctioned editorial subtitle
/// pattern (see CLAUDE.md ➜ Code Rules).
struct WelcomeScreen: View {
    let onEnter: () -> Void

    var body: some View {
        ZStack {
            Theme.Editorial.dayGradient.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                masthead
                    .padding(.bottom, 88)

                MAAuthHero(
                    line1: "When was the last time you did something",
                    line2: "for the first time?"
                )

                Spacer()

                MAAuthSub(text: "— A QUESTION TO BEGIN WITH")
                    .padding(.bottom, 28)

                MAPrimaryButton(title: "ENTER", trailingArrow: true, action: onEnter)
            }
            .padding(.horizontal, Theme.Editorial.Spacing.pad)
            .padding(.top, 90)
            .padding(.bottom, 64)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var masthead: some View {
        VStack(spacing: 6) {
            MAWordmark()
            Text("VOL · 02 · MMXXVI")
                .font(Theme.Editorial.Typography.caps(8, weight: .semibold))
                .tracking(2.4)
                .foregroundStyle(Theme.Editorial.onSurfaceFaint)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview("01 Welcome") {
    WelcomeScreen(onEnter: {})
}
