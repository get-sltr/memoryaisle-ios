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
    }

    private func clearSession() {
        deleteFromKeychain(key: "ma_email")
        deleteFromKeychain(key: "ma_token")
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
