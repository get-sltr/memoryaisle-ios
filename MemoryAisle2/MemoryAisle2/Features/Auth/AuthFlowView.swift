import AuthenticationServices
import SwiftUI

enum AuthScreen {
    case signIn
    case signUp
    case verify
}

struct AuthFlowView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(AppState.self) private var appState
    @State private var authManager = CognitoAuthManager()
    @State private var screen: AuthScreen = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var verifyCode = ""
    @State private var showLegal: LegalPage?

    var body: some View {
        ZStack {
            Color.clear

            VStack(spacing: 0) {
                switch screen {
                case .signIn:
                    signInView
                case .signUp:
                    signUpView
                case .verify:
                    verifyView
                }
            }
        }
        .themeBackground()
        .sheet(item: $showLegal) { page in LegalView(page: page) }
        .task {
            await authManager.restoreSession()
            if authManager.isSignedIn {
                appState.authStatus = .signedIn
            }
        }
    }

    // MARK: - Sign In

    private var signInView: some View {
        VStack(spacing: 0) {
            Spacer()

            OnboardingLogo(size: 160)
                .padding(.bottom, 24)

            Text("Welcome back")
                .font(Typography.serifLarge)
                .foregroundStyle(Theme.Text.primary)
                .tracking(0.3)
                .padding(.bottom, 32)

            VStack(spacing: 12) {
                authField("Email", text: $email, keyboard: .emailAddress)
                authField("Password", text: $password, isSecure: true)
            }
            .padding(.horizontal, 32)

            if let error = authManager.error {
                Text(error)
                    .font(Typography.bodySmall)
                    .foregroundStyle(Theme.Semantic.warning(for: scheme))
                    .padding(.top, 12)
                    .padding(.horizontal, 32)
                    .accessibilityLabel("Error: \(error)")
            }

            Spacer()

            VStack(spacing: 14) {
                // Apple Sign In
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.email, .fullName]
                } onCompletion: { result in
                    handleAppleSignIn(result)
                }
                .signInWithAppleButtonStyle(.white)
                .frame(height: 50)
                .clipShape(Capsule())

                // Divider
                HStack {
                    Rectangle()
                        .fill(Theme.Text.tertiary(for: scheme))
                        .frame(height: 0.5)
                    Text("or")
                        .font(Typography.caption)
                        .foregroundStyle(Theme.Text.tertiary(for: scheme))
                    Rectangle()
                        .fill(Theme.Text.tertiary(for: scheme))
                        .frame(height: 0.5)
                }

                // Email Sign In
                GlowButton(authManager.isLoading ? "Signing in..." : "Sign in with email") {
                    Task {
                        if await authManager.signIn(email: email, password: password) {
                            HapticManager.success()
                            appState.authStatus = .signedIn
                        }
                    }
                }

                Button {
                    screen = .signUp
                    authManager.error = nil
                } label: {
                    Text("Don't have an account? **Sign up**")
                        .font(Typography.bodyMedium)
                        .foregroundStyle(Theme.Text.secondary(for: scheme))
                }
                .accessibilityLabel("Don't have an account? Sign up")
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 56)
        }
    }

    // MARK: - Sign Up

    private var signUpView: some View {
        VStack(spacing: 0) {
            // Back
            HStack {
                DismissButton {
                    screen = .signIn
                    authManager.error = nil
                }
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.top, 4)

            Spacer()

            MiraWaveform(state: .speaking, size: .hero)
                .frame(height: 50)
                .padding(.bottom, 32)

            Text("Create your account")
                .font(Typography.serifLarge)
                .foregroundStyle(Theme.Text.primary)
                .tracking(0.3)
                .padding(.bottom, 32)

            VStack(spacing: 12) {
                authField("Email", text: $email, keyboard: .emailAddress)
                authField("Password", text: $password, isSecure: true)
            }
            .padding(.horizontal, 32)

            Text("8+ characters, uppercase, lowercase, number")
                .font(Typography.caption)
                .foregroundStyle(Theme.Text.tertiary(for: scheme))
                .padding(.top, 8)

            VStack(spacing: 2) {
                Text("By signing up, you agree to our")
                    .font(Typography.caption)
                    .foregroundStyle(Theme.Text.tertiary(for: scheme))
                HStack(spacing: 4) {
                    Button { showLegal = .terms } label: {
                        Text("Terms of Service")
                            .font(Typography.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.violet)
                            .underline()
                    }
                    .accessibilityLabel("View Terms of Service")
                    Text("and")
                        .font(Typography.caption)
                        .foregroundStyle(Theme.Text.tertiary(for: scheme))
                    Button { showLegal = .privacy } label: {
                        Text("Privacy Policy")
                            .font(Typography.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.violet)
                            .underline()
                    }
                    .accessibilityLabel("View Privacy Policy")
                }
            }
            .padding(.top, 4)

            if let error = authManager.error {
                Text(error)
                    .font(Typography.bodySmall)
                    .foregroundStyle(Theme.Semantic.warning(for: scheme))
                    .padding(.top, 12)
                    .padding(.horizontal, 32)
                    .accessibilityLabel("Error: \(error)")
            }

            Spacer()

            VStack(spacing: 14) {
                GlowButton(authManager.isLoading ? "Creating account..." : "Sign up") {
                    Task {
                        if await authManager.signUp(email: email, password: password) {
                            HapticManager.success()
                            screen = .verify
                        }
                    }
                }

                Button {
                    screen = .signIn
                    authManager.error = nil
                } label: {
                    Text("Already have an account? **Sign in**")
                        .font(Typography.bodyMedium)
                        .foregroundStyle(Theme.Text.secondary(for: scheme))
                }
                .accessibilityLabel("Already have an account? Sign in")
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 56)
        }
    }

    // MARK: - Verify

    private var verifyView: some View {
        VStack(spacing: 0) {
            HStack {
                DismissButton {
                    screen = .signUp
                    authManager.error = nil
                }
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.top, 4)

            Spacer()

            MiraWaveform(state: .thinking, size: .hero)
                .frame(height: 50)
                .padding(.bottom, 32)

            Text("Check your email")
                .font(Typography.serifLarge)
                .foregroundStyle(Theme.Text.primary)
                .tracking(0.3)

            Text("We sent a verification code to\n\(email)")
                .font(Typography.bodyMedium)
                .foregroundStyle(Theme.Text.secondary(for: scheme))
                .multilineTextAlignment(.center)
                .padding(.top, 8)
                .padding(.bottom, 32)

            authField("Verification code", text: $verifyCode, keyboard: .numberPad)
                .padding(.horizontal, 32)

            if let error = authManager.error {
                Text(error)
                    .font(Typography.bodySmall)
                    .foregroundStyle(Theme.Semantic.warning(for: scheme))
                    .padding(.top, 12)
                    .padding(.horizontal, 32)
                    .accessibilityLabel("Error: \(error)")
            }

            Spacer()

            GlowButton(authManager.isLoading ? "Verifying..." : "Verify") {
                Task {
                    if await authManager.confirmSignUp(email: email, code: verifyCode) {
                        // Auto sign in after verify
                        if await authManager.signIn(email: email, password: password) {
                            HapticManager.success()
                            appState.authStatus = .signedIn
                        }
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 56)
        }
    }

    // MARK: - Auth Field

    private func authField(
        _ placeholder: String,
        text: Binding<String>,
        keyboard: UIKeyboardType = .default,
        isSecure: Bool = false
    ) -> some View {
        Group {
            if isSecure {
                SecureField(placeholder, text: text)
            } else {
                TextField(placeholder, text: text)
                    .keyboardType(keyboard)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
        }
        .font(Typography.bodyLarge)
        .foregroundStyle(Theme.Text.primary)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.Surface.glass(for: scheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Theme.Border.glass(for: scheme), lineWidth: Theme.glassBorderWidth)
        )
        .accessibilityLabel(placeholder)
    }

    // MARK: - Apple Sign In

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            if let credential = auth.credential as? ASAuthorizationAppleIDCredential {
                let userId = credential.user
                let email = credential.email ?? ""
                let name = [
                    credential.fullName?.givenName,
                    credential.fullName?.familyName
                ].compactMap { $0 }.joined(separator: " ")

                // Store Apple user ID
                UserDefaults.standard.set(userId, forKey: "ma_apple_user_id")
                if !email.isEmpty {
                    UserDefaults.standard.set(email, forKey: "ma_email")
                }
                if !name.isEmpty {
                    UserDefaults.standard.set(name, forKey: "ma_name")
                }

                HapticManager.success()
                appState.authStatus = .signedIn
            }
        case .failure:
            authManager.error = "Apple Sign In failed. Please try again."
        }
    }
}
