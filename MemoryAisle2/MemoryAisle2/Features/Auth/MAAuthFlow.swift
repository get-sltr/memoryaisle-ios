import AuthenticationServices
import OSLog
import SwiftData
import SwiftUI

/// Editorial auth flow router. Owns the `CognitoAuthManager` instance,
/// runs the post-signin hook (App Reviewer seed + Pro override refresh),
/// flips `appState.authStatus`, and routes between the six screens via
/// NavigationStack.
///
/// Welcome is first-run only — gated by the `ma_seen_welcome` UserDefault
/// and recorded the first time the user taps ENTER.
///
/// `confirmSignUp` is reachable from Sign Up's success path (Cognito
/// requires email verification before first sign-in); the screen reuses
/// `CheckEmailScreen` + a simple inline code prompt when needed. For now
/// the post-signup verify screen is folded into a Sign-In retry loop —
/// the user receives the code, comes back, signs in once Cognito has
/// confirmed them. A dedicated post-signup verify screen is a follow-up.
struct MAAuthFlow: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Environment(SubscriptionManager.self) private var subscriptionManager

    @State private var authManager = CognitoAuthManager()
    @State private var path: [MAAuthRoute] = []
    @State private var hasSeenWelcome: Bool = UserDefaults.standard.bool(forKey: "ma_seen_welcome")
    @State private var legalSheet: LegalPage?

    /// Password held transiently between SignUp success and confirmSignup
    /// success so the router can auto-sign-in the user the moment Cognito
    /// flips them from `unconfirmed` to `confirmed`. Cleared as soon as the
    /// auto-signin completes (or fails) so it doesn't linger in memory
    /// longer than necessary.
    @State private var pendingSignupPassword: String?

    private let logger = Logger(subsystem: "com.memoryaisle.Auth", category: "Flow")

    var body: some View {
        NavigationStack(path: $path) {
            rootScreen
                .navigationDestination(for: MAAuthRoute.self) { route in
                    destination(for: route)
                }
        }
        .sheet(item: $legalSheet) { page in
            LegalView(page: page)
        }
        .task {
            await authManager.restoreSession()
            if authManager.isSignedIn {
                handlePostSignIn(email: authManager.email)
                appState.authStatus = .signedIn
            }
        }
    }

    @ViewBuilder
    private var rootScreen: some View {
        if hasSeenWelcome {
            SignInScreen(
                authManager: authManager,
                onForgotPassword: { path.append(.forgotPassword) },
                onCreateAccount: { path.append(.signUp) },
                onAuthSuccess: handleAuthSuccess(email:),
                onAppleResult: handleAppleResult(_:),
                onTapLegal: { legalSheet = $0 }
            )
        } else {
            WelcomeScreen(onEnter: enterFromWelcome)
        }
    }

    @ViewBuilder
    private func destination(for route: MAAuthRoute) -> some View {
        switch route {
        case .signIn:
            SignInScreen(
                authManager: authManager,
                onForgotPassword: { path.append(.forgotPassword) },
                onCreateAccount: { path.append(.signUp) },
                onAuthSuccess: handleAuthSuccess(email:),
                onAppleResult: handleAppleResult(_:),
                onTapLegal: { legalSheet = $0 }
            )
        case .signUp:
            SignUpScreen(
                authManager: authManager,
                onSignInInstead: { path.removeLast() },
                onSignUpCodeSent: { email, password in
                    pendingSignupPassword = password
                    path.append(.confirmSignup(email: email))
                },
                onAuthSuccess: handleAuthSuccess(email:),
                onAppleResult: handleAppleResult(_:),
                onTapLegal: { legalSheet = $0 }
            )
        case .confirmSignup(let email):
            PostSignupConfirmScreen(
                authManager: authManager,
                email: email,
                onConfirmed: {
                    Task { await completeSignupSignIn(email: email) }
                }
            )
        case .forgotPassword:
            ForgotPasswordScreen(
                authManager: authManager,
                onCodeSent: { email in path.append(.checkEmail(email: email)) },
                onSignInInstead: { path.removeLast() }
            )
        case .checkEmail(let email):
            CheckEmailScreen(
                authManager: authManager,
                email: email,
                onEnterCode: { path.append(.resetPassword(email: email)) },
                onUseDifferentEmail: { path.removeLast() }
            )
        case .resetPassword(let email):
            ResetPasswordScreen(
                authManager: authManager,
                email: email,
                onAuthSuccess: handleAuthSuccess(email:)
            )
        }
    }

    // MARK: - Post-signup auto signin

    /// After Cognito accepts the confirmation code, sign the user in
    /// using the password they typed on SignUp. Clears the in-memory
    /// password regardless of outcome so it doesn't linger.
    private func completeSignupSignIn(email: String) async {
        defer { pendingSignupPassword = nil }
        guard let password = pendingSignupPassword else {
            // No stored password — fall back to Sign In; the user types
            // their credentials again. Their account is confirmed at
            // this point so the next signIn will succeed.
            path = []
            authManager.error = "Account confirmed. Please sign in."
            return
        }
        let ok = await authManager.signIn(email: email, password: password)
        if ok { handleAuthSuccess(email: email) }
    }

    // MARK: - First-run welcome gate

    private func enterFromWelcome() {
        UserDefaults.standard.set(true, forKey: "ma_seen_welcome")
        withAnimation(.easeInOut(duration: 0.25)) {
            hasSeenWelcome = true
        }
    }

    // MARK: - Apple sign-in handler

    /// Native ASAuthorization handler. Persists user identifiers to
    /// UserDefaults (the existing `ma_apple_user_id` / `ma_email` /
    /// `ma_name` keys, matching production), then runs the post-signin
    /// hook and flips `appState.authStatus`. Lifted from the legacy
    /// `AuthFlowView.handleAppleSignIn(_:)` to keep behavior identical.
    private func handleAppleResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else { return }
            let userId = credential.user
            let email = credential.email ?? ""
            let name = [credential.fullName?.givenName, credential.fullName?.familyName]
                .compactMap { $0 }.joined(separator: " ")

            UserDefaults.standard.set(userId, forKey: "ma_apple_user_id")
            if !email.isEmpty { UserDefaults.standard.set(email, forKey: "ma_email") }
            if !name.isEmpty { UserDefaults.standard.set(name, forKey: "ma_name") }

            HapticManager.success()
            handleAuthSuccess(email: email.isEmpty ? nil : email)
        case .failure(let err):
            logger.error("Apple sign-in failed: \(err.localizedDescription, privacy: .public)")
            authManager.error = "Apple sign in failed. Please try again."
        }
    }

    // MARK: - Shared post-signin path

    private func handleAuthSuccess(email: String?) {
        handlePostSignIn(email: email)
        appState.authStatus = .signedIn
    }

    /// Mirror of `AuthFlowView.handlePostSignIn` — must run after every
    /// success path (Apple, email signin, signup-then-signin, reset-then-
    /// signin) or Pro tier visibility and the App Reviewer seed will not
    /// fire correctly. Does NOT touch local SwiftData; MemoryAisle is a
    /// longitudinal journey app and sign-in/out must preserve user data.
    private func handlePostSignIn(email: String?) {
        AppReviewerSeedService.handleSignIn(email: email, modelContext: modelContext)
        subscriptionManager.refreshOverrides()
    }
}

// MARK: - Routes

enum MAAuthRoute: Hashable {
    case signIn
    case signUp
    case confirmSignup(email: String)
    case forgotPassword
    case checkEmail(email: String)
    case resetPassword(email: String)
}

#Preview("Full Auth Flow") {
    MAAuthFlow()
        .environment(AppState())
        .environment(SubscriptionManager())
        .modelContainer(for: UserProfile.self, inMemory: true)
}
