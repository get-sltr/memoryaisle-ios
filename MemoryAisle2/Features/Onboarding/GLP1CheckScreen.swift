import SwiftUI

struct GLP1CheckScreen: View {
    let onYes: () -> Void
    let onNo: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            MiraWaveform(state: .idle, size: .inline)
                .padding(.bottom, Theme.Spacing.xl)

            Text("Are you on\nGLP-1 medication?")
                .font(Typography.displayMedium)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.bottom, Theme.Spacing.xxl)

            VStack(spacing: Theme.Spacing.md) {
                VioletButton("Yes, I'm on a GLP-1 medication") {
                    onYes()
                }

                GhostButton("No, I just want smarter nutrition") {
                    onNo()
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)

            Spacer()
            Spacer()
        }
    }
}
