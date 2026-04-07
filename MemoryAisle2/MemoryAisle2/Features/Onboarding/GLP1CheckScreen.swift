import SwiftUI

struct GLP1CheckScreen: View {
    let onYes: () -> Void
    let onNo: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            Spacer()

            MiraWaveform(state: .idle, size: .inline)
                .frame(height: 30)
                .padding(.bottom, 40)

            Text("Are you on\nGLP-1 medication?")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            Spacer()
            Spacer()

            VStack(spacing: 14) {
                VioletButton("Yes, I'm on a GLP-1") {
                    onYes()
                }

                GhostButton("No, I just want smarter nutrition") {
                    onNo()
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 56)
        }
    }
}
