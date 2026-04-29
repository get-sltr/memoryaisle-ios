import SwiftUI

/// Screen 6 of 6 — Reset Password.
/// User has the code from email; types it plus a new password (twice).
/// Live match indicator. On success, the screen auto-signs-in via
/// `onAuthSuccess(email)` so the router can run `handlePostSignIn` and
/// flip `appState.authStatus`.
struct ResetPasswordScreen: View {
    let authManager: CognitoAuthManager
    let email: String
    let onAuthSuccess: (_ email: String?) -> Void

    @State private var code: String = ""
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""

    private var passwordsMatch: Bool {
        !newPassword.isEmpty && newPassword == confirmPassword
    }

    private var canSubmit: Bool {
        code.count >= 6 && passwordsMatch
    }

    var body: some View {
        ZStack {
            Theme.Editorial.dayGradient.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    MAWordmark()
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 24)

                    MAAuthHero(line1: "Choose your", line2: "new password.")
                        .padding(.bottom, 8)
                    MAAuthSub(text: "— ALMOST THERE")
                        .padding(.bottom, 28)

                    Spacer(minLength: 12)

                    MAAuthField(
                        label: "VERIFICATION CODE",
                        text: $code,
                        placeholder: "Paste the 6-digit code",
                        keyboardType: .numberPad,
                        textContentType: .oneTimeCode
                    )
                    .padding(.bottom, 18)

                    MAAuthPasswordField(
                        label: "NEW PASSWORD",
                        password: $newPassword,
                        placeholder: "Create a new password",
                        textContentType: .newPassword
                    )

                    Text("8+ CHARACTERS · LETTERS & NUMBERS")
                        .font(Theme.Editorial.Typography.caps(8, weight: .medium))
                        .tracking(1.4)
                        .foregroundStyle(Theme.Editorial.onSurfaceFaint)
                        .padding(.top, 4)
                        .padding(.bottom, 18)

                    MAAuthPasswordField(
                        label: "CONFIRM PASSWORD",
                        password: $confirmPassword,
                        placeholder: "Type it once more",
                        textContentType: .newPassword
                    )

                    matchIndicator
                        .padding(.top, 4)
                        .padding(.bottom, 16)

                    MAPrimaryButton(title: "SET NEW PASSWORD") {
                        guard canSubmit else { return }
                        Task {
                            let updated = await authManager.confirmResetPassword(
                                email: email,
                                code: code,
                                newPassword: newPassword
                            )
                            guard updated else { return }
                            // Auto sign-in so the user lands inside the app
                            // without a second prompt. handlePostSignIn runs
                            // via the router's onAuthSuccess closure.
                            let signedIn = await authManager.signIn(
                                email: email,
                                password: newPassword
                            )
                            if signedIn { onAuthSuccess(email) }
                        }
                    }
                    .disabled(!canSubmit)
                    .opacity(canSubmit ? 1.0 : 0.5)

                    if let error = authManager.error {
                        MAAuthErrorLine(message: error)
                            .padding(.top, 12)
                    }
                }
                .padding(.horizontal, Theme.Editorial.Spacing.pad)
                .padding(.top, 56)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)

            if authManager.isLoading { MALoadingOverlay() }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    @ViewBuilder
    private var matchIndicator: some View {
        if confirmPassword.isEmpty {
            Color.clear.frame(height: 14)
        } else if passwordsMatch {
            Text("PASSWORDS MATCH ✓")
                .font(Theme.Editorial.Typography.caps(8, weight: .semibold))
                .tracking(1.4)
                .foregroundStyle(Theme.Editorial.onSurfaceMuted)
                .frame(height: 14, alignment: .leading)
        } else {
            Text("PASSWORDS DON'T MATCH")
                .font(Theme.Editorial.Typography.caps(8, weight: .semibold))
                .tracking(1.4)
                .foregroundStyle(Color(red: 1.0, green: 0.85, blue: 0.85))
                .frame(height: 14, alignment: .leading)
        }
    }
}

#Preview("06 Reset Password") {
    NavigationStack {
        ResetPasswordScreen(
            authManager: CognitoAuthManager(),
            email: "kev@sltrdigital.com",
            onAuthSuccess: { _ in }
        )
    }
}
