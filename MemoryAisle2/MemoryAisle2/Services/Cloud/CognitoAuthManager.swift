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
                self.email = email

                // Get user info
                await fetchUser()
                isSignedIn = true
                saveSession(email: email, token: accessToken)
            }
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

    /// Sign in with Apple entry point. Apple does not issue a renewable
    /// access token the way Cognito does — subsequent sign-ins only
    /// return the stable Apple user ID. The session therefore persists
    /// via UserDefaults keyed on that ID, and the install marker is
    /// set so `restoreSession` on the next cold launch will trust it.
    /// Email is recorded only on Apple's first-ever SIWA response for a
    /// given app/user pair, so callers should always persist what they
    /// get; we won't see it again.
    func saveAppleSession(appleUserID: String, email: String?, name: String?) {
        UserDefaults.standard.set(appleUserID, forKey: "ma_apple_user_id")
        if let email, !email.isEmpty {
            UserDefaults.standard.set(email, forKey: "ma_email")
            self.email = email
        }
        if let name, !name.isEmpty {
            UserDefaults.standard.set(name, forKey: "ma_name")
        }
        UserDefaults.standard.set(true, forKey: Self.installMarkerKey)
        isSignedIn = true
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

    /// UserDefaults marker used to detect a fresh install. Keychain
    /// items persist across app deletes but UserDefaults does not, so
    /// if this key is missing while Keychain holds credentials, the
    /// app was just reinstalled on a device that previously had a
    /// signed-in account. For a health app with medication data we
    /// don't want those credentials silently restored — the new user
    /// (or the same user on a device that may have changed hands) is
    /// required to sign in again.
    private static let installMarkerKey = "ma_install_initialized_v1"

    func restoreSession() async {
        if !UserDefaults.standard.bool(forKey: Self.installMarkerKey) {
            clearSession()
            return
        }

        // Sign in with Apple path: Apple never returns a renewable
        // token for subsequent sign-ins, so the SIWA session is
        // represented solely by the stable Apple user ID stored in
        // UserDefaults. When that marker is present the user is
        // considered signed in — this removes the pre-existing bug
        // where SIWA users had to re-authenticate on every cold launch.
        if UserDefaults.standard.string(forKey: "ma_apple_user_id") != nil {
            email = UserDefaults.standard.string(forKey: "ma_email")
            isSignedIn = true
            return
        }

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
        } else {
            clearSession()
        }
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

    private func saveSession(email: String?, token: String?) {
        if let email { saveToKeychain(key: "ma_email", value: email) }
        if let token { saveToKeychain(key: "ma_token", value: token) }
        // Mark the install as initialized so a subsequent cold launch
        // restoreSession() will trust the Keychain credentials. Without
        // this, restoreSession treats the next launch as a fresh install
        // and wipes the session.
        UserDefaults.standard.set(true, forKey: Self.installMarkerKey)
    }

    private func clearSession() {
        deleteFromKeychain(key: "ma_email")
        deleteFromKeychain(key: "ma_token")
        UserDefaults.standard.removeObject(forKey: "ma_email")
        UserDefaults.standard.removeObject(forKey: "ma_token")
        // Sign in with Apple markers — without these a signed-out SIWA
        // user would still look signed-in to restoreSession on the
        // next cold launch.
        UserDefaults.standard.removeObject(forKey: "ma_apple_user_id")
        UserDefaults.standard.removeObject(forKey: "ma_name")
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

    /// Email for the currently signed-in account, or nil if no session
    /// is active. Read from Keychain first (where email is stored after
    /// migration) with a UserDefaults fallback for Sign in with Apple
    /// users whose email landed there first. Settings uses this to show
    /// the user which account they are signed in under.
    nonisolated static func currentEmail() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.sltrdigital.memoryaisle",
            kSecAttrAccount as String: "ma_email",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess,
           let data = result as? Data,
           let email = String(data: data, encoding: .utf8),
           !email.isEmpty {
            return email
        }
        if let email = UserDefaults.standard.string(forKey: "ma_email"),
           !email.isEmpty {
            return email
        }
        return nil
    }

    /// True if the current session was established via Sign in with
    /// Apple rather than Cognito email/password. Used by Settings to
    /// display the correct sign-in method indicator.
    nonisolated static func isSignedInWithApple() -> Bool {
        UserDefaults.standard.string(forKey: "ma_apple_user_id") != nil
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
