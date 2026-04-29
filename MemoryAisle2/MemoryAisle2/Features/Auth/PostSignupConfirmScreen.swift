import SwiftUI

/// Post-signup email confirmation. Cognito mails a 6-digit code after a
/// successful `signUp`; the user types it here to flip the account from
/// `unconfirmed` to `confirmed`. On success the router auto-signs-them-in
/// using the password the SignUp screen captured a moment earlier (held
/// transiently in `MAAuthFlow.pendingSignupPassword`), so the user lands
/// in the app without typing their credentials a second time.
///
/// No back bar — confirming is a forward-only step. If the user backgrounds
/// the app and reopens, the router resets to Sign In; they can sign in
/// directly if Cognito has by then accepted the code from a clicked email
/// link, or contact support if their code never arrived.
struct PostSignupConfirmScreen: View {
    let authManager: CognitoAuthManager
    let email: String
    let onConfirmed: () -> Void

    @State private var code: String = ""

    private var canSubmit: Bool { code.count >= 6 }

    var body: some View {
        ZStack {
            Theme.Editorial.dayGradient.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    MAWordmark()
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 24)

                    MAAuthHero(line1: "A code,", line2: "and you're in.")
                        .padding(.bottom, 8)
                    MAAuthSub(text: "— ONE LAST STEP")
                        .padding(.bottom, 22)

                    Text("We sent a 6-digit code to \(email). Type it back here to confirm your account.")
                        .font(.system(size: 16, weight: .regular, design: .serif))
                        .italic()
                        .lineSpacing(2)
                        .foregroundStyle(Theme.Editorial.onSurfaceMuted)
                        .padding(.bottom, 32)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer(minLength: 24)

                    MAAuthField(
                        label: "VERIFICATION CODE",
                        text: $code,
                        placeholder: "Paste the 6-digit code",
                        keyboardType: .numberPad,
                        textContentType: .oneTimeCode
                    )
                    .padding(.bottom, 28)

                    MAPrimaryButton(title: "CONFIRM ACCOUNT") {
                        guard canSubmit else { return }
                        Task {
                            let confirmed = await authManager.confirmSignUp(email: email, code: code)
                            if confirmed { onConfirmed() }
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
}

#Preview("Post-Signup Confirm") {
    NavigationStack {
        PostSignupConfirmScreen(
            authManager: CognitoAuthManager(),
            email: "kev@sltrdigital.com",
            onConfirmed: {}
        )
    }
}
