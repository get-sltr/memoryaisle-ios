import SwiftUI

struct ChangeEmailSheet: View {
    let onDone: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var auth = CognitoAuthManager()

    @State private var step: Step = .enterEmail
    @State private var newEmail: String = ""
    @State private var code: String = ""

    private enum Step {
        case enterEmail
        case enterCode
        case complete
    }

    var body: some View {
        ZStack {
            EditorialBackground(mode: appState.effectiveAppearanceMode)

            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Button {
                        dismiss()
                        onDone()
                    } label: {
                        Text("CLOSE")
                            .font(Theme.Editorial.Typography.capsBold(11))
                            .tracking(2.0)
                            .foregroundStyle(Theme.Editorial.onSurface.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }

                Text("CHANGE EMAIL")
                    .font(Theme.Editorial.Typography.caps(10, weight: .semibold))
                    .tracking(3.0)
                    .foregroundStyle(Theme.Editorial.onSurface.opacity(0.7))

                switch step {
                case .enterEmail:
                    TextField("new@email.com", text: $newEmail)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .font(.system(size: 18, design: .serif))
                        .foregroundStyle(Theme.Editorial.onSurface)
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Theme.Editorial.onSurface.opacity(0.08))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Theme.Editorial.onSurface.opacity(0.2), lineWidth: 0.5)
                        )

                    Button {
                        Task { await requestChange() }
                    } label: {
                        sheetPrimaryButtonLabel("SEND CODE")
                    }
                    .buttonStyle(.plain)
                    .disabled(auth.isLoading || newEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                case .enterCode:
                    Text("Check your new email for a verification code.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.Editorial.onSurface.opacity(0.7))

                    TextField("Code", text: $code)
                        .keyboardType(.numberPad)
                        .font(.system(size: 18, design: .serif))
                        .foregroundStyle(Theme.Editorial.onSurface)
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Theme.Editorial.onSurface.opacity(0.08))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Theme.Editorial.onSurface.opacity(0.2), lineWidth: 0.5)
                        )

                    Button {
                        Task { await confirmChange() }
                    } label: {
                        sheetPrimaryButtonLabel("CONFIRM")
                    }
                    .buttonStyle(.plain)
                    .disabled(auth.isLoading || code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                case .complete:
                    Text("Email updated.")
                        .font(.system(size: 16, weight: .regular, design: .serif))
                        .foregroundStyle(Theme.Editorial.onSurface)
                    Button {
                        dismiss()
                        onDone()
                    } label: {
                        sheetPrimaryButtonLabel("DONE")
                    }
                    .buttonStyle(.plain)
                }

                if let error = auth.error, !error.isEmpty {
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.Editorial.onSurface.opacity(0.75))
                        .padding(.top, 6)
                }

                Spacer()
            }
            .padding(28)
        }
        .preferredColorScheme(.light)
        .presentationDetents([.medium, .large])
        .onAppear {
            Task { await auth.restoreSession() }
            newEmail = UserDefaults.standard.string(forKey: "ma_email") ?? ""
        }
    }

    private func requestChange() async {
        let emailTrimmed = newEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !emailTrimmed.isEmpty else { return }
        let ok = await auth.requestEmailChange(to: emailTrimmed)
        if ok {
            step = .enterCode
        }
    }

    private func confirmChange() async {
        let emailTrimmed = newEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        let codeTrimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !emailTrimmed.isEmpty, !codeTrimmed.isEmpty else { return }
        let ok = await auth.confirmEmailChange(newEmail: emailTrimmed, code: codeTrimmed)
        if ok {
            UserDefaults.standard.set(emailTrimmed, forKey: "ma_email")
            step = .complete
        }
    }

    private func sheetPrimaryButtonLabel(_ title: String) -> some View {
        Text(title)
            .font(Theme.Editorial.Typography.capsBold(11))
            .tracking(2.0)
            .foregroundStyle(Color(red: 0.961, green: 0.851, blue: 0.478))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Theme.Editorial.onSurface.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Theme.Editorial.onSurface.opacity(0.2), lineWidth: 0.5)
            )
    }
}

struct ChangePasswordSheet: View {
    let onDone: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var auth = CognitoAuthManager()

    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var didSucceed = false

    var body: some View {
        ZStack {
            EditorialBackground(mode: appState.effectiveAppearanceMode)

            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Button {
                        dismiss()
                        onDone()
                    } label: {
                        Text("CLOSE")
                            .font(Theme.Editorial.Typography.capsBold(11))
                            .tracking(2.0)
                            .foregroundStyle(Theme.Editorial.onSurface.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }

                Text("CHANGE PASSWORD")
                    .font(Theme.Editorial.Typography.caps(10, weight: .semibold))
                    .tracking(3.0)
                    .foregroundStyle(Theme.Editorial.onSurface.opacity(0.7))

                if didSucceed {
                    Text("Password updated.")
                        .font(.system(size: 16, weight: .regular, design: .serif))
                        .foregroundStyle(Theme.Editorial.onSurface)
                    Button {
                        dismiss()
                        onDone()
                    } label: {
                        sheetPrimaryButtonLabel("DONE")
                    }
                    .buttonStyle(.plain)
                } else {
                    SecureField("Current password", text: $currentPassword)
                        .textInputAutocapitalization(.never)
                        .font(.system(size: 18, design: .serif))
                        .foregroundStyle(Theme.Editorial.onSurface)
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Theme.Editorial.onSurface.opacity(0.08))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Theme.Editorial.onSurface.opacity(0.2), lineWidth: 0.5)
                        )

                    SecureField("New password", text: $newPassword)
                        .textInputAutocapitalization(.never)
                        .font(.system(size: 18, design: .serif))
                        .foregroundStyle(Theme.Editorial.onSurface)
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Theme.Editorial.onSurface.opacity(0.08))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Theme.Editorial.onSurface.opacity(0.2), lineWidth: 0.5)
                        )

                    SecureField("Confirm new password", text: $confirmPassword)
                        .textInputAutocapitalization(.never)
                        .font(.system(size: 18, design: .serif))
                        .foregroundStyle(Theme.Editorial.onSurface)
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Theme.Editorial.onSurface.opacity(0.08))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Theme.Editorial.onSurface.opacity(0.2), lineWidth: 0.5)
                        )

                    Button {
                        Task { await submitPasswordChange() }
                    } label: {
                        sheetPrimaryButtonLabel("UPDATE")
                    }
                    .buttonStyle(.plain)
                    .disabled(auth.isLoading || !canSubmit)
                }

                if let error = auth.error, !error.isEmpty {
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.Editorial.onSurface.opacity(0.75))
                        .padding(.top, 6)
                }

                Spacer()
            }
            .padding(28)
        }
        .preferredColorScheme(.light)
        .presentationDetents([.large])
        .onAppear { Task { await auth.restoreSession() } }
    }

    private var canSubmit: Bool {
        !currentPassword.isEmpty
            && !newPassword.isEmpty
            && newPassword == confirmPassword
    }

    private func submitPasswordChange() async {
        guard canSubmit else { return }
        let ok = await auth.changePassword(currentPassword: currentPassword, newPassword: newPassword)
        if ok {
            didSucceed = true
            currentPassword = ""
            newPassword = ""
            confirmPassword = ""
        }
    }

    private func sheetPrimaryButtonLabel(_ title: String) -> some View {
        Text(title)
            .font(Theme.Editorial.Typography.capsBold(11))
            .tracking(2.0)
            .foregroundStyle(Color(red: 0.961, green: 0.851, blue: 0.478))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Theme.Editorial.onSurface.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Theme.Editorial.onSurface.opacity(0.2), lineWidth: 0.5)
            )
    }
}

