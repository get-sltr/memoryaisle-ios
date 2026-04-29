import AuthenticationServices
import SwiftUI

/// Screen 2 of 6 — Sign In.
/// Apple-first per HIG, email + password fallback, forgot-password link,
/// legal footer, switcher to Sign Up.
struct SignInScreen: View {
    let authManager: CognitoAuthManager
    let onForgotPassword: () -> Void
    let onCreateAccount: () -> Void
    let onAuthSuccess: (_ email: String?) -> Void
    let onAppleResult: (Result<ASAuthorization, Error>) -> Void
    let onTapLegal: (LegalPage) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var email: String = ""
    @State private var password: String = ""

    var body: some View {
        ZStack {
            Theme.Editorial.dayGradient.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    MAAuthTopBar { dismiss() }
                        .padding(.bottom, 24)

                    MAAuthHero(line1: "Sign in,", line2: "continue your story.")
                        .padding(.bottom, 8)
                    MAAuthSub(text: "— WELCOME BACK")
                        .padding(.bottom, 56)

                    appleButton
                        .padding(.bottom, 16)

                    MALabeledDivider(label: "OR SIGN IN WITH EMAIL")
                        .padding(.bottom, 22)

                    MAAuthField(
                        label: "EMAIL",
                        text: $email,
                        keyboardType: .emailAddress,
                        textContentType: .emailAddress
                    )
                    .padding(.bottom, 18)

                    MAAuthPasswordField(label: "PASSWORD", password: $password)
                        .padding(.bottom, 16)

                    forgotLink
                        .padding(.bottom, 18)

                    MASecondaryButton(title: "SIGN IN") {
                        Task {
                            let ok = await authManager.signIn(email: email, password: password)
                            if ok { onAuthSuccess(email) }
                        }
                    }
                    .padding(.bottom, 24)

                    if let error = authManager.error {
                        MAAuthErrorLine(message: error)
                            .padding(.bottom, 12)
                    }

                    createAccountSwitch
                        .padding(.bottom, 18)

                    MAAuthLegal(
                        preamble: "BY CONTINUING, YOU AGREE TO OUR",
                        onTap: onTapLegal
                    )
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

    private var appleButton: some View {
        SignInWithAppleButton(.signIn) { request in
            request.requestedScopes = [.email, .fullName]
        } onCompletion: { result in
            onAppleResult(result)
        }
        .signInWithAppleButtonStyle(.black)
        .frame(height: 50)
        .frame(maxWidth: 420)
        .frame(maxWidth: .infinity)
    }

    private var forgotLink: some View {
        HStack {
            Spacer()
            Button(action: onForgotPassword) {
                Text("Forgot password?")
                    .font(Theme.Editorial.Typography.caps(9, weight: .semibold))
                    .tracking(2)
                    .foregroundStyle(Theme.Editorial.onSurface)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(Theme.Editorial.onSurface.opacity(0.75))
                            .frame(height: 0.5)
                            .offset(y: 1)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Forgot password")
        }
    }

    private var createAccountSwitch: some View {
        HStack(spacing: 6) {
            Spacer()
            Text("New to MemoryAisle?")
                .font(Theme.Editorial.Typography.caps(10, weight: .medium))
                .tracking(2)
                .foregroundStyle(Theme.Editorial.onSurface)
            Button(action: onCreateAccount) {
                Text("CREATE ACCOUNT")
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
            .accessibilityLabel("Create account")
            Spacer()
        }
    }
}

#Preview("02 Sign In") {
    NavigationStack {
        SignInScreen(
            authManager: CognitoAuthManager(),
            onForgotPassword: {},
            onCreateAccount: {},
            onAuthSuccess: { _ in },
            onAppleResult: { _ in },
            onTapLegal: { _ in }
        )
    }
}
