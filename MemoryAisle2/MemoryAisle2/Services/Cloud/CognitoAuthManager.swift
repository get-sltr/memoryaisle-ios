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
    private(set) var refreshToken: String?
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
                refreshToken = result["RefreshToken"] as? String
                self.email = email

                try? await fetchUser()
                isSignedIn = true
                saveSession(email: email, token: accessToken, refresh: refreshToken)
            }
            isLoading = false
            return true
        } catch {
            self.error = parseError(error)
            isLoading = false
            return false
        }
    }

    // MARK: - Sign in with Apple

    /// Sign in with Apple entry point. Apple does not issue a renewable
    /// access token the way Cognito does — subsequent sign-ins only return
    /// the stable Apple user ID. The session therefore persists via
    /// UserDefaults keyed on that ID; restoreSession on the next cold
    /// launch checks for `ma_apple_user_id` and trusts it without a
    /// Cognito round-trip. Email is recorded only on Apple's first-ever
    /// SIWA response for a given app/user pair, so callers should always
    /// persist what they get; we won't see it again.
    func saveAppleSession(appleUserID: String, email: String?, name: String?) {
        UserDefaults.standard.set(appleUserID, forKey: "ma_apple_user_id")
        if let email, !email.isEmpty {
            UserDefaults.standard.set(email, forKey: "ma_email")
            self.email = email
        }
        if let name, !name.isEmpty {
            UserDefaults.standard.set(name, forKey: "ma_name")
        }
        isSignedIn = true
    }

    // MARK: - Sign Out

    /// Minimal sign-out: clears in-memory auth state and the keychain.
    /// Prefer `signOutEverywhere(modelContext:subscription:)` from UI
    /// code so local user data, the reviewer Pro override, and the
    /// subscription tier are all reset together.
    func signOut() {
        isSignedIn = false
        accessToken = nil
        refreshToken = nil
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
    static func signOutEverywhere(
        modelContext: ModelContext,
        subscription: SubscriptionManager
    ) async {
        AppReviewerSeedService.clearReviewerFlag()

        CognitoAuthManager().signOut()

        await subscription.updateSubscriptionStatus()
    }

    // MARK: - Restore Session

    /// Resolves auth state on cold launch.
    ///
    /// Three paths, in order of precedence:
    /// 1. **Sign in with Apple.** If `ma_apple_user_id` is present, the
    ///    user signed in with Apple — Apple never issues a renewable
    ///    Cognito token, so the marker is the source of truth. Trust it
    ///    and skip the Cognito round-trip entirely.
    /// 2. **Cognito with valid token.** GetUser returns 200, we're done.
    /// 3. **Cognito with expired token.** Try the refresh-token flow once.
    ///    On success, store the new access token and retry GetUser. On
    ///    permanent failure (no refresh token, refresh token also
    ///    expired) clear the keychain and fall back to signed-out.
    ///
    /// **Critical invariant:** transient failures (network down, Cognito
    /// 5xx, DNS hiccup) must NOT wipe the keychain. Previously any
    /// `fetchUser` failure cleared the session, so a single network blip
    /// on launch produced a permanent sign-out — the bug this rewrite
    /// fixes. On a transient error we keep `isSignedIn = true` (the
    /// access token may still be valid; later API calls will retry on
    /// their own) but never delete the saved tokens.
    func restoreSession() async {
        // 1. Apple SIWA short-circuit.
        if UserDefaults.standard.string(forKey: "ma_apple_user_id") != nil {
            email = UserDefaults.standard.string(forKey: "ma_email")
            isSignedIn = true
            return
        }

        // 2. Read Cognito tokens from keychain (with one-time UserDefaults migration).
        var savedEmail = readFromKeychain(key: "ma_email")
        var savedToken = readFromKeychain(key: "ma_token")
        let savedRefresh = readFromKeychain(key: "ma_refresh")

        if savedEmail == nil, let udEmail = UserDefaults.standard.string(forKey: "ma_email") {
            savedEmail = udEmail
            savedToken = UserDefaults.standard.string(forKey: "ma_token")
            saveSession(email: savedEmail, token: savedToken, refresh: nil)
            UserDefaults.standard.removeObject(forKey: "ma_email")
            UserDefaults.standard.removeObject(forKey: "ma_token")
        }

        guard let savedEmail, let savedToken else { return }

        email = savedEmail
        accessToken = savedToken
        refreshToken = savedRefresh

        // 3. Validate against Cognito GetUser, refreshing if expired.
        do {
            try await fetchUser()
            isSignedIn = true
        } catch AuthError.tokenExpired {
            await handleExpiredAccessToken()
        } catch {
            // Network or 5xx — stay optimistic, keep keychain intact.
            // Subsequent API calls will retry; better than punting the
            // user back to sign-in over a transient blip.
            isSignedIn = true
        }
    }

    private func handleExpiredAccessToken() async {
        guard let newToken = await tryRefreshAccessToken() else {
            // No refresh token, or refresh itself returned tokenExpired.
            // The session is genuinely over — clear it.
            clearSession()
            isSignedIn = false
            accessToken = nil
            refreshToken = nil
            return
        }

        accessToken = newToken
        saveToKeychain(key: "ma_token", value: newToken)

        do {
            try await fetchUser()
            isSignedIn = true
        } catch AuthError.tokenExpired {
            // New token already rejected — abandon ship.
            clearSession()
            isSignedIn = false
            accessToken = nil
            refreshToken = nil
        } catch {
            // Transient on the retry — stay optimistic.
            isSignedIn = true
        }
    }

    /// Trades a stored refresh token for a fresh access token. Cognito's
    /// REFRESH_TOKEN_AUTH does not return a new refresh token; the
    /// existing one stays valid until its server-configured TTL (30 days
    /// by default), so we only persist the new access token.
    /// Returns nil when no refresh token is stored, or when Cognito
    /// rejects the refresh — in either case the caller treats this as a
    /// genuine sign-out.
    private func tryRefreshAccessToken() async -> String? {
        guard let refresh = refreshToken else { return nil }

        let body: [String: Any] = [
            "AuthFlow": "REFRESH_TOKEN_AUTH",
            "ClientId": clientId,
            "AuthParameters": [
                "REFRESH_TOKEN": refresh
            ]
        ]

        do {
            let data = try await cognitoRequest(
                action: "AWSCognitoIdentityProviderService.InitiateAuth",
                body: body
            )
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let result = json["AuthenticationResult"] as? [String: Any],
               let newToken = result["AccessToken"] as? String {
                return newToken
            }
            return nil
        } catch AuthError.tokenExpired {
            return nil
        } catch {
            // Transient failure — return nil to leave the session
            // untouched. Caller's transient-error path keeps the user
            // signed-in optimistically rather than wiping over a blip.
            return nil
        }
    }

    // MARK: - Fetch User

    private func fetchUser() async throws {
        guard let token = accessToken else {
            throw AuthError.tokenExpired
        }

        let body: [String: Any] = [
            "AccessToken": token
        ]

        let data = try await cognitoRequest(
            action: "AWSCognitoIdentityProviderService.GetUser",
            body: body
        )
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
            userId = json["Username"] as? String
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

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw AuthError.networkError
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.networkError
        }

        if httpResponse.statusCode != 200 {
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let type = (json?["__type"] as? String) ?? ""
            let message = (json?["message"] as? String) ?? "Request failed (\(httpResponse.statusCode))"

            // Cognito returns NotAuthorizedException for both expired-token
            // and wrong-password. Distinguish by message so a sign-in with
            // bad credentials doesn't get re-routed through the refresh
            // path as if a session had merely expired.
            if type.contains("NotAuthorizedException") {
                let lower = message.lowercased()
                if lower.contains("token") && (lower.contains("expired") || lower.contains("invalid") || lower.contains("revoked")) {
                    throw AuthError.tokenExpired
                }
            }
            throw AuthError.serverError(message)
        }

        return data
    }

    // MARK: - Session Persistence (Keychain)

    private let keychainService = "com.sltrdigital.memoryaisle"

    private func saveSession(email: String?, token: String?, refresh: String?) {
        if let email { saveToKeychain(key: "ma_email", value: email) }
        if let token { saveToKeychain(key: "ma_token", value: token) }
        if let refresh { saveToKeychain(key: "ma_refresh", value: refresh) }
    }

    private func clearSession() {
        deleteFromKeychain(key: "ma_email")
        deleteFromKeychain(key: "ma_token")
        deleteFromKeychain(key: "ma_refresh")
        UserDefaults.standard.removeObject(forKey: "ma_email")
        UserDefaults.standard.removeObject(forKey: "ma_token")
        // SIWA markers — without these a signed-out Apple user would
        // still look signed-in to restoreSession on the next cold launch.
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
    case tokenExpired
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .networkError: "Network connection failed"
        case .tokenExpired: "Your session expired. Please sign in again."
        case .serverError(let msg): msg
        }
    }
}
