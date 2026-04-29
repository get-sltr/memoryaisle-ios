import SwiftUI

/// Screen 4 of 6 — Forgot Password.
/// Single email field. On submit, Cognito mails a 6-digit code to the
/// address (whether or not it actually exists, by design).
struct ForgotPasswordScreen: View {
    let authManager: CognitoAuthManager
    let onCodeSent: (_ email: String) -> Void
    let onSignInInstead: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var email: String = ""

    var body: some View {
        ZStack {
            Theme.Editorial.dayGradient.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                MAAuthTopBar { dismiss() }
                    .padding(.bottom, 24)

                MAAuthHero(line1: "A new password,", line2: "in a moment.")
                    .padding(.bottom, 8)
                MAAuthSub(text: "— RESET YOUR PASSWORD")
                    .padding(.bottom, 22)

                Text("Enter your email and we'll send a code. Type it back here, choose a new password, and you're in.")
                    .font(.system(size: 16, weight: .regular, design: .serif))
                    .italic()
                    .lineSpacing(2)
                    .foregroundStyle(Theme.Editorial.onSurfaceMuted)
                    .padding(.bottom, 32)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 32)

                MAAuthField(
                    label: "EMAIL",
                    text: $email,
                    placeholder: "you@email.com",
                    keyboardType: .emailAddress,
                    textContentType: .emailAddress
                )
                .padding(.bottom, 28)

                MAPrimaryButton(title: "SEND RESET CODE") {
                    Task {
                        let sent = await authManager.resetPassword(email: email)
                        if sent { onCodeSent(email) }
                    }
                }
                .padding(.bottom, 16)

                if let error = authManager.error {
                    MAAuthErrorLine(message: error)
                        .padding(.bottom, 12)
                }

                signInSwitch
            }
            .padding(.horizontal, Theme.Editorial.Spacing.pad)
            .padding(.top, 56)
            .padding(.bottom, 40)

            if authManager.isLoading { MALoadingOverlay() }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var signInSwitch: some View {
        HStack(spacing: 6) {
            Spacer()
            Text("Remembered it?")
                .font(Theme.Editorial.Typography.caps(10, weight: .medium))
                .tracking(2)
                .foregroundStyle(Theme.Editorial.onSurface)
            Button(action: onSignInInstead) {
                Text("SIGN IN")
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
            .buttonStyle(.plain)
            .accessibilityLabel("Sign in")
            Spacer()
        }
    }
}

#Preview("04 Forgot Password") {
    NavigationStack {
        ForgotPasswordScreen(
            authManager: CognitoAuthManager(),
            onCodeSent: { _ in },
            onSignInInstead: {}
        )
    }
}
