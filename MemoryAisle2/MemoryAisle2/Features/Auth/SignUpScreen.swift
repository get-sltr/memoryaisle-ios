import AuthenticationServices
import SwiftUI

/// Screen 3 of 6 — Sign Up.
/// Apple-first, name + email + password, password rule hint, legal footer
/// required pre-account-creation per Apple Review 5.1.1(v).
struct SignUpScreen: View {
    let authManager: CognitoAuthManager
    let onSignInInstead: () -> Void
    let onSignUpCodeSent: (_ email: String, _ password: String) -> Void
    let onAuthSuccess: (_ email: String?) -> Void
    let onAppleResult: (Result<ASAuthorization, Error>) -> Void
    let onTapLegal: (LegalPage) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var email: String = ""
    @State private var password: String = ""

    var body: some View {
        ZStack {
            Theme.Editorial.dayGradient.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    MAAuthTopBar { dismiss() }
                        .padding(.bottom, 24)

                    MAAuthHero(line1: "Begin,", line2: "at your own pace.")
                        .padding(.bottom, 8)
                    MAAuthSub(text: "— A NEW ACCOUNT")
                        .padding(.bottom, 36)

                    appleButton
                        .padding(.bottom, 16)

                    MALabeledDivider(label: "OR SIGN UP WITH EMAIL")
                        .padding(.bottom, 22)

                    MAAuthField(
                        label: "YOUR NAME",
                        text: $name,
                        placeholder: "What should we call you?",
                        textContentType: .givenName,
                        autocapitalization: .words
                    )
                    .padding(.bottom, 16)

                    MAAuthField(
                        label: "EMAIL",
                        text: $email,
                        placeholder: "you@email.com",
                        keyboardType: .emailAddress,
                        textContentType: .emailAddress
                    )
                    .padding(.bottom, 16)

                    MAAuthPasswordField(
                        label: "PASSWORD",
                        password: $password,
                        placeholder: "Create a password",
                        textContentType: .newPassword
                    )

                    Text("8+ CHARACTERS · LETTERS & NUMBERS")
                        .font(Theme.Editorial.Typography.caps(8, weight: .medium))
                        .tracking(1.4)
                        .foregroundStyle(Theme.Editorial.onSurfaceFaint)
                        .padding(.top, 4)
                        .padding(.bottom, 24)

                    MAPrimaryButton(title: "CREATE ACCOUNT") {
                        Task {
                            let ok = await authManager.signUp(email: email, password: password)
                            if ok {
                                // Cognito requires email confirmation; the
                                // verify code is sent to the address above.
                                // Hand off to the post-signup confirm flow,
                                // passing the password so the router can
                                // auto-sign-in once Cognito accepts the code.
                                onSignUpCodeSent(email, password)
                            }
                        }
                    }
                    .padding(.bottom, 16)

                    if let error = authManager.error {
                        MAAuthErrorLine(message: error)
                            .padding(.bottom, 12)
                    }

                    MAAuthLegal(
                        preamble: "BY CREATING AN ACCOUNT, YOU AGREE TO OUR",
                        onTap: onTapLegal
                    )
                    .padding(.bottom, 22)

                    signInSwitch
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
        SignInWithAppleButton(.signUp) { request in
            request.requestedScopes = [.email, .fullName]
        } onCompletion: { result in
            onAppleResult(result)
        }
        .signInWithAppleButtonStyle(.black)
        .frame(height: 50)
        .frame(maxWidth: 420)
        .frame(maxWidth: .infinity)
    }

    private var signInSwitch: some View {
        HStack(spacing: 6) {
            Spacer()
            Text("Already have an account?")
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

#Preview("03 Sign Up") {
    NavigationStack {
        SignUpScreen(
            authManager: CognitoAuthManager(),
            onSignInInstead: {},
            onSignUpCodeSent: { _, _ in },
            onAuthSuccess: { _ in },
            onAppleResult: { _ in },
            onTapLegal: { _ in }
        )
    }
}
