import SwiftUI

struct GLP1CheckScreen: View {
    @Environment(\.colorScheme) private var scheme
    let onYes: () -> Void
    let onNo: () -> Void

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: geo.size.height * 0.25)

                OnboardingLogo()
                    .padding(.bottom, 40)

                Text("Are you on\nGLP-1 medication?")
                    .font(.system(size: 28, weight: .light, design: .serif))
                    .foregroundStyle(Theme.Text.primary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .tracking(0.3)

                Spacer()

                VStack(spacing: 14) {
                    GlowButton("Yes, I'm on a GLP-1") {
                        onYes()
                    }

                    Button {
                        HapticManager.light()
                        onNo()
                    } label: {
                        Text("No, I just want smarter nutrition")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(Theme.Text.secondary(for: scheme))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 56)
            }
        }
    }
}
