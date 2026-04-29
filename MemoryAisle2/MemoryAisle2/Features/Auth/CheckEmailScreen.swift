import SwiftUI

/// Screen 5 of 6 — Check Email.
/// Confirmation that the reset code is on its way. Numbered steps for
/// what to do next, primary CTA to enter the code, RESEND + USE A
/// DIFFERENT EMAIL escape hatches.
struct CheckEmailScreen: View {
    let authManager: CognitoAuthManager
    let email: String
    let onEnterCode: () -> Void
    let onUseDifferentEmail: () -> Void

    var body: some View {
        ZStack {
            Theme.Editorial.dayGradient.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                MAWordmark()
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 24)

                MAAuthHero(line1: "Check your", line2: "inbox.")
                    .padding(.bottom, 8)
                MAAuthSub(text: "— CODE SENT")
                    .padding(.bottom, 24)

                sentToBlock
                    .padding(.bottom, 22)

                stepsList

                Spacer()

                MAPrimaryButton(title: "I HAVE THE CODE", action: onEnterCode)
                    .padding(.bottom, 14)

                resendBlock
            }
            .padding(.horizontal, Theme.Editorial.Spacing.pad)
            .padding(.top, 56)
            .padding(.bottom, 40)

            if authManager.isLoading { MALoadingOverlay() }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var sentToBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("SENT TO")
                .font(Theme.Editorial.Typography.capsBold(9))
                .tracking(2.0)
                .foregroundStyle(Theme.Editorial.onSurfaceMuted)
            Text(email)
                .font(.system(size: 18, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(Theme.Editorial.onSurface)
        }
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.Editorial.onSurface.opacity(0.7)).frame(height: 1)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.Editorial.onSurface.opacity(0.7)).frame(height: 1)
        }
    }

    private var stepsList: some View {
        VStack(alignment: .leading, spacing: 14) {
            stepRow(num: "01", text: "Open the email from MemoryAisle.")
            stepRow(num: "02", text: "Copy the 6-digit code inside.")
            stepRow(num: "03", text: "Tap the button below and paste it.")
        }
    }

    private var resendBlock: some View {
        VStack(spacing: 6) {
            Text("Didn't receive it?")
                .font(Theme.Editorial.Typography.caps(9, weight: .semibold))
                .tracking(2)
                .foregroundStyle(Theme.Editorial.onSurfaceMuted)

            HStack(spacing: 14) {
                Button {
                    Task { _ = await authManager.resetPassword(email: email) }
                } label: {
                    underlineLink("RESEND")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Resend code")

                Text("·").foregroundStyle(Theme.Editorial.onSurfaceFaint)

                Button(action: onUseDifferentEmail) {
                    underlineLink("USE A DIFFERENT EMAIL")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Use a different email")
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func stepRow(num: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(num)
                .font(Theme.Editorial.Typography.capsBold(9))
                .tracking(1.6)
                .foregroundStyle(Theme.Editorial.onSurfaceMuted)
                .padding(.top, 4)
                .frame(minWidth: 22, alignment: .leading)
            Text(text)
                .font(.system(size: 15, weight: .regular, design: .serif))
                .lineSpacing(2)
                .foregroundStyle(Theme.Editorial.onSurface)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func underlineLink(_ text: String) -> some View {
        Text(text)
            .font(Theme.Editorial.Typography.capsBold(10))
            .tracking(2)
            .foregroundStyle(Theme.Editorial.onSurface)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Theme.Editorial.onSurface.opacity(0.85))
                    .frame(height: 0.5)
                    .offset(y: 1)
            }
    }
}

#Preview("05 Check Email") {
    NavigationStack {
        CheckEmailScreen(
            authManager: CognitoAuthManager(),
            email: "kev@sltrdigital.com",
            onEnterCode: {},
            onUseDifferentEmail: {}
        )
    }
}
