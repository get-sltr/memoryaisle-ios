import Foundation
import Security
import SwiftData

@MainActor
@Observable
final class CognitoAuthManager {
    private(set) var isSignedIn = false
    private(set) var isLoading = false
    private(set) var userId: String?
    private(set) var email: String?
    private(set) var accessToken: String?
    var error: String?

    private let userPoolId = "us-east-1_8jluiv1HL"
    private let clientId = "724lhhilciamunsh13vj5pf753"
    private let region = "us-east-1"

    private var baseURL: String {
        "https://cognito-idp.\(region).amazonaws.com"
    }

    // MARK: - Sign Up

    func signUp(email: String, password: String) async -> Bool {
        isLoading = true
        error = nil

        let body: [String: Any] = [
            "ClientId": clientId,
            "Username": email,
            "Password": password,
            "UserAttributes": [
                ["Name": "email", "Value": email]
            ]
        ]

        do {
            let _ = try await cognitoRequest(action: "AWSCognitoIdentityProviderService.SignUp", body: body)
            isLoading = false
            return true
        } catch {
            self.error = parseError(error)
            isLoading = false
            return false
        }
    }

    // MARK: - Confirm Sign Up

    func confirmSignUp(email: String, code: String) async -> Bool {
        isLoading = true
        error = nil

        let body: [String: Any] = [
            "ClientId": clientId,
            "Username": email,
            "ConfirmationCode": code
        ]

        do {
            let _ = try await cognitoRequest(action: "AWSCognitoIdentityProviderService.ConfirmSignUp", body: body)
            isLoading = false
            return true
        } catch {
            self.error = parseError(error)
            isLoading = false
            return false
        }
    }

    // MARK: - Sign In

    func signIn(email: String, password: String) async -> Bool {
        isLoading = true
        error = nil

        let body: [String: Any] = [
            "AuthFlow": "USER_PASSWORD_AUTH",
            "ClientId": clientId,
            "AuthParameters": [
                "USERNAME": email,
                "PASSWORD": password
            ]
        ]

        do {
            let data = try await cognitoRequest(action: "AWSCognitoIdentityProviderService.InitiateAuth", body: body)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let result = json["AuthenticationResult"] as? [String: Any] {
                accessToken = result["AccessToken"] as? String
                let refreshToken = result["RefreshToken"] as? String
                self.email = email

                // Get user info
                await fetchUser()
                isSignedIn = true
                saveSession(email: email, token: accessToken, refreshToken: refreshToken)
            }
            isLoading = false
            return true
        } catch {
            self.error = parseError(error)
            isLoading = false
            return false
        }
    }

    // MARK: - Reset Password

    /// Asks Cognito to mail a 6-digit reset code to `email` if an account
    /// exists with that username. Cognito does NOT confirm whether the
    /// account exists — that prevents account enumeration — so a `true`
    /// return means "request accepted," not "account found." Returns
    /// false and sets `error` on transport or service failure.
    func resetPassword(email: String) async -> Bool {
        isLoading = true
        error = nil

        let body: [String: Any] = [
            "ClientId": clientId,
            "Username": email
        ]

        do {
            _ = try await cognitoRequest(action: "AWSCognitoIdentityProviderService.ForgotPassword", body: body)
            isLoading = false
            return true
        } catch {
            self.error = parseError(error)
            isLoading = false
            return false
        }
    }

    /// Confirms the reset by submitting the mailed code along with the
    /// new password. On success the account password is updated; the
    /// caller should follow up with `signIn(email:password:)` to
    /// establish a session. Returns false and sets `error` on code
    /// mismatch, expired code, weak password, or transport failure.
    func confirmResetPassword(email: String, code: String, newPassword: String) async -> Bool {
        isLoading = true
        error = nil

        let body: [String: Any] = [
            "ClientId": clientId,
            "Username": email,
            "ConfirmationCode": code,
            "Password": newPassword
        ]

        do {
            _ = try await cognitoRequest(action: "AWSCognitoIdentityProviderService.ConfirmForgotPassword", body: body)
            isLoading = false
            return true
        } catch {
            self.error = parseError(error)
            isLoading = false
            return false
        }
    }

    // MARK: - Sign Out

    /// Minimal sign-out: clears in-memory auth state and the keychain.
    /// Prefer `signOutEverywhere(modelContext:subscription:)` from UI
    /// code so local user data, the reviewer Pro override, and the
    /// subscription tier are all reset together.
    func signOut() {
        isSignedIn = false
        accessToken = nil
        userId = nil
        email = nil
        clearSession()
    }

    /// Coordinated sign-out used by the Profile Sign Out button and
    /// the "Delete All Data" flow. Does **not** purge local SwiftData —
    /// MemoryAisle is a longitudinal journey app, so a user signing
    /// out in week 4 must find their logs, medication cycle, check-ins
    /// and saved recipes intact when they sign back in. Multi-user /
    /// account-switch privacy is handled on sign-**in** instead, by
    /// `AuthFlowView.handlePostSignIn` which diffs the incoming email
    /// against the last signed-in email and wipes only when the
    /// account actually changes.
    ///
    /// This function:
    /// 1. Clears the App Reviewer Pro override (`clearReviewerFlag`)
    ///    so the next user on this device is not granted Pro.
    /// 2. Tears down keychain + in-memory auth state.
    /// 3. Re-evaluates the subscription tier so any stale Pro state
    ///    from the previous session is dropped (a real paid StoreKit
    ///    entitlement survives and is correctly restored).
    static func signOutEverywhere(
        modelContext: ModelContext,
        subscription: SubscriptionManager
    ) async {
        AppReviewerSeedService.clearReviewerFlag()

        CognitoAuthManager().signOut()

        await subscription.updateSubscriptionStatus()
    }

    // MARK: - Restore Session

    /// Re-establishes the signed-in state from keychain on app launch.
    ///
    /// Flow:
    ///   1. Load saved email + access token from keychain (migrate from
    ///      UserDefaults if needed).
    ///   2. Try `fetchUser()` with the saved access token.
    ///   3. If that succeeds (userId populated), we're signed in. Done.
    ///   4. If it fails (token expired/invalid), try the refresh-token
    ///      flow to mint a new access token, then retry `fetchUser()`.
    ///   5. Only if BOTH the access token and the refresh attempt fail
    ///      do we leave `isSignedIn = false`. We do NOT call
    ///      `clearSession()` here — silent sign-out without the user's
    ///      explicit decision is a hard rule. The keychain stays intact
    ///      so the sign-in screen can prefill email and the user can
    ///      re-auth without losing local state. Only `signOut()` and
    ///      `signOutEverywhere()` (both user-initiated) clear the keychain.
    func restoreSession() async {
        var savedEmail = readFromKeychain(key: "ma_email")
        var savedToken = readFromKeychain(key: "ma_token")

        // Migrate from UserDefaults if Keychain is empty
        if savedEmail == nil, let udEmail = UserDefaults.standard.string(forKey: "ma_email") {
            savedEmail = udEmail
            savedToken = UserDefaults.standard.string(forKey: "ma_token")
            saveSession(email: savedEmail, token: savedToken)
            UserDefaults.standard.removeObject(forKey: "ma_email")
            UserDefaults.standard.removeObject(forKey: "ma_token")
        }

        guard let savedEmail, let savedToken else { return }

        email = savedEmail
        accessToken = savedToken

        await fetchUser()
        if userId != nil {
            isSignedIn = true
            return
        }

        // Access token didn't validate. Try refresh before giving up.
        if await refreshAccessToken() {
            await fetchUser()
            if userId != nil {
                isSignedIn = true
                return
            }
        }

        // Refresh also failed. Leave signed-out state, but do NOT wipe
        // the keychain — the user did not ask to sign out. They will be
        // routed to MAAuthFlow with email prefilled; on next successful
        // sign-in, saveSession overwrites the stale tokens.
    }

    /// Calls Cognito's REFRESH_TOKEN_AUTH flow to mint a new access token
    /// from the saved refresh token. Returns true when a new access token
    /// was obtained and persisted; false when no refresh token is stored
    /// or the refresh call failed (network error, refresh token revoked,
    /// or refresh token expired — Cognito refresh tokens default to 30
    /// days but can be configured longer in the user pool).
    private func refreshAccessToken() async -> Bool {
        guard let refreshToken = readFromKeychain(key: "ma_refresh_token") else {
            return false
        }

        let body: [String: Any] = [
            "AuthFlow": "REFRESH_TOKEN_AUTH",
            "ClientId": clientId,
            "AuthParameters": [
                "REFRESH_TOKEN": refreshToken
            ]
        ]

        do {
            let data = try await cognitoRequest(action: "AWSCognitoIdentityProviderService.InitiateAuth", body: body)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let result = json["AuthenticationResult"] as? [String: Any],
               let newAccessToken = result["AccessToken"] as? String {
                accessToken = newAccessToken
                saveToKeychain(key: "ma_token", value: newAccessToken)
                // REFRESH_TOKEN_AUTH only returns a new RefreshToken when
                // the pool is configured to rotate them; reuse the existing
                // refresh token when a new one isn't returned.
                if let newRefresh = result["RefreshToken"] as? String {
                    saveToKeychain(key: "ma_refresh_token", value: newRefresh)
                }
                return true
            }
        } catch {
            // Refresh failed — refresh token revoked, expired, or transient
            // network error. Caller will leave isSignedIn = false; no wipe.
        }
        return false
    }

    // MARK: - Fetch User

    private func fetchUser() async {
        guard let token = accessToken else { return }

        let body: [String: Any] = [
            "AccessToken": token
        ]

        do {
            let data = try await cognitoRequest(action: "AWSCognitoIdentityProviderService.GetUser", body: body)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                userId = json["Username"] as? String
            }
        } catch {
            // Token expired
            accessToken = nil
        }
    }

    // MARK: - Account updates (signed-in)

    /// Changes the signed-in user's password using the current access token.
    func changePassword(currentPassword: String, newPassword: String) async -> Bool {
        isLoading = true
        error = nil

        guard let token = accessToken else {
            isLoading = false
            error = "Please sign in again."
            return false
        }

        let body: [String: Any] = [
            "AccessToken": token,
            "PreviousPassword": currentPassword,
            "ProposedPassword": newPassword,
        ]

        do {
            _ = try await cognitoRequest(action: "AWSCognitoIdentityProviderService.ChangePassword", body: body)
            isLoading = false
            return true
        } catch {
            self.error = parseError(error)
            isLoading = false
            return false
        }
    }

    /// Requests an email change for the signed-in user. Cognito typically
    /// requires verification; call `confirmEmailChange(code:)` after the
    /// user enters the code mailed to the new address.
    func requestEmailChange(to newEmail: String) async -> Bool {
        isLoading = true
        error = nil

        guard let token = accessToken else {
            isLoading = false
            error = "Please sign in again."
            return false
        }

        let body: [String: Any] = [
            "AccessToken": token,
            "UserAttributes": [
                ["Name": "email", "Value": newEmail],
            ],
        ]

        do {
            _ = try await cognitoRequest(action: "AWSCognitoIdentityProviderService.UpdateUserAttributes", body: body)
            isLoading = false
            return true
        } catch {
            self.error = parseError(error)
            isLoading = false
            return false
        }
    }

    /// Confirms the pending email change by submitting the verification code.
    func confirmEmailChange(newEmail: String, code: String) async -> Bool {
        isLoading = true
        error = nil

        guard let token = accessToken else {
            isLoading = false
            error = "Please sign in again."
            return false
        }

        let body: [String: Any] = [
            "AccessToken": token,
            "AttributeName": "email",
            "Code": code,
        ]

        do {
            _ = try await cognitoRequest(action: "AWSCognitoIdentityProviderService.VerifyUserAttribute", body: body)
            email = newEmail
            saveSession(email: newEmail, token: accessToken)
            isLoading = false
            return true
        } catch {
            self.error = parseError(error)
            isLoading = false
            return false
        }
    }

    // MARK: - Network

    private func cognitoRequest(action: String, body: [String: Any]) async throws -> Data {
        guard let url = URL(string: baseURL) else { throw AuthError.networkError }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-amz-json-1.1", forHTTPHeaderField: "Content-Type")
        request.setValue(action, forHTTPHeaderField: "X-Amz-Target")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.networkError
        }

        if httpResponse.statusCode != 200 {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = json["message"] as? String {
                throw AuthError.serverError(message)
            }
            throw AuthError.serverError("Request failed (\(httpResponse.statusCode))")
        }

        return data
    }

    // MARK: - Session Persistence (Keychain)

    private let keychainService = "com.sltrdigital.memoryaisle"

    private func saveSession(email: String?, token: String?, refreshToken: String? = nil) {
        if let email { saveToKeychain(key: "ma_email", value: email) }
        if let token { saveToKeychain(key: "ma_token", value: token) }
        if let refreshToken { saveToKeychain(key: "ma_refresh_token", value: refreshToken) }
    }

    private func clearSession() {
        deleteFromKeychain(key: "ma_email")
        deleteFromKeychain(key: "ma_token")
        deleteFromKeychain(key: "ma_refresh_token")
        UserDefaults.standard.removeObject(forKey: "ma_email")
        UserDefaults.standard.removeObject(forKey: "ma_token")
    }

    private func saveToKeychain(key: String, value: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    private func readFromKeychain(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func deleteFromKeychain(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }

    private func parseError(_ error: Error) -> String {
        if let authError = error as? AuthError {
            return authError.localizedDescription
        }
        return error.localizedDescription
    }

    // MARK: - Static Helpers

    /// Returns the signed-in user's Cognito `sub` as a UUID by reading
    /// the stored access token from the keychain and decoding its JWT
    /// payload. Used by the purchase flow so StoreKit can tag each
    /// transaction with `appAccountToken`, which lets the server-side
    /// App Store Server Notifications handler correlate events back to
    /// this user. Returns nil when there is no saved session, the token
    /// is malformed, or `sub` is absent.
    nonisolated static func currentUserUUID() -> UUID? {
        guard let token = readStoredAccessToken(),
              let sub = decodeJWTSub(token) else { return nil }
        return UUID(uuidString: sub)
    }

    private nonisolated static func readStoredAccessToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.sltrdigital.memoryaisle",
            kSecAttrAccount as String: "ma_token",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private nonisolated static func decodeJWTSub(_ token: String) -> String? {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return nil }

        var payload = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while payload.count % 4 != 0 { payload.append("=") }

        guard let data = Data(base64Encoded: payload),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sub = json["sub"] as? String else { return nil }
        return sub
    }

    /// Reads the `cognito:groups` claim from the stored access token.
    /// Used by `AppReviewerSeedService` to gate the reviewer Pro override
    /// behind Cognito group membership the email check alone can't
    /// prevent squatting against. Returns an empty array when no token
    /// is stored or the claim is absent.
    nonisolated static func currentUserGroups() -> [String] {
        guard let token = readStoredAccessToken(),
              let groups = decodeJWTGroups(token) else { return [] }
        return groups
    }

    private nonisolated static func decodeJWTGroups(_ token: String) -> [String]? {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var payload = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while payload.count % 4 != 0 { payload.append("=") }
        guard let data = Data(base64Encoded: payload),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let groups = json["cognito:groups"] as? [String] else { return nil }
        return groups
    }
}

enum AuthError: LocalizedError {
    case networkError
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .networkError: "Network connection failed"
        case .serverError(let msg): msg
        }
    }
}
