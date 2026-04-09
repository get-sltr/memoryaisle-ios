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

            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .padding(.bottom, 24)

            Text("Welcome back")
                .font(.system(size: 28, weight: .light, design: .serif))
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
                    .font(.system(size: 13))
                    .foregroundStyle(Color(hex: 0xF87171))
                    .padding(.top, 12)
                    .padding(.horizontal, 32)
            }

            Spacer()

            VStack(spacing: 14) {
                GlowButton(authManager.isLoading ? "Signing in..." : "Sign in") {
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
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.Text.secondary(for: scheme))
                }
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
                Button {
                    screen = .signIn
                    authManager.error = nil
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Theme.Text.secondary(for: scheme))
                        .frame(width: 44, height: 44)
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
                .font(.system(size: 28, weight: .light, design: .serif))
                .foregroundStyle(Theme.Text.primary)
                .tracking(0.3)
                .padding(.bottom, 32)

            VStack(spacing: 12) {
                authField("Email", text: $email, keyboard: .emailAddress)
                authField("Password", text: $password, isSecure: true)
            }
            .padding(.horizontal, 32)

            Text("8+ characters, uppercase, lowercase, number")
                .font(.system(size: 11))
                .foregroundStyle(Theme.Text.tertiary(for: scheme))
                .padding(.top, 8)

            if let error = authManager.error {
                Text(error)
                    .font(.system(size: 13))
                    .foregroundStyle(Color(hex: 0xF87171))
                    .padding(.top, 12)
                    .padding(.horizontal, 32)
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
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.Text.secondary(for: scheme))
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 56)
        }
    }

    // MARK: - Verify

    private var verifyView: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    screen = .signUp
                    authManager.error = nil
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Theme.Text.secondary(for: scheme))
                        .frame(width: 44, height: 44)
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
                .font(.system(size: 28, weight: .light, design: .serif))
                .foregroundStyle(Theme.Text.primary)
                .tracking(0.3)

            Text("We sent a verification code to\n\(email)")
                .font(.system(size: 14))
                .foregroundStyle(Theme.Text.secondary(for: scheme))
                .multilineTextAlignment(.center)
                .padding(.top, 8)
                .padding(.bottom, 32)

            authField("Verification code", text: $verifyCode, keyboard: .numberPad)
                .padding(.horizontal, 32)

            if let error = authManager.error {
                Text(error)
                    .font(.system(size: 13))
                    .foregroundStyle(Color(hex: 0xF87171))
                    .padding(.top, 12)
                    .padding(.horizontal, 32)
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
        .font(.system(size: 16))
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
    }
}
