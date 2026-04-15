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

    /// Full sign-out used by the Profile Sign Out button and the
    /// "Delete All Data" flow. In order:
    ///
    /// 1. Clear the App Reviewer Pro override so the next user on this
    ///    device is not granted Pro.
    /// 2. Delete every user-owned SwiftData row from the shared
    ///    container. Without this, signing in as a different user on
    ///    the same device would inherit the previous user's profile,
    ///    nutrition logs, symptoms, medication history, check-ins, and
    ///    saved recipes — a shared-device privacy leak.
    /// 3. Tear down keychain + in-memory auth state (the existing
    ///    `signOut()` path).
    /// 4. Re-evaluate subscription tier so any stale Pro state from
    ///    the previous session is dropped.
    static func signOutEverywhere(
        modelContext: ModelContext,
        subscription: SubscriptionManager
    ) async {
        AppReviewerSeedService.clearReviewerFlag()

        // Every user-owned model type registered in the shared
        // container. Mirror this list if a new SwiftData type is added
        // in `MemoryAisleApp.modelContainer(for:)`.
        try? modelContext.delete(model: UserProfile.self)
        try? modelContext.delete(model: NutritionLog.self)
        try? modelContext.delete(model: SymptomLog.self)
        try? modelContext.delete(model: MedicationProfile.self)
        try? modelContext.delete(model: BodyComposition.self)
        try? modelContext.delete(model: TrainingSession.self)
        try? modelContext.delete(model: PantryItem.self)
        try? modelContext.delete(model: GIToleranceRecord.self)
        try? modelContext.delete(model: FoodItem.self)
        try? modelContext.delete(model: Meal.self)
        try? modelContext.delete(model: MealPlan.self)
        try? modelContext.delete(model: GroceryList.self)
        try? modelContext.delete(model: ProviderReport.self)
        try? modelContext.delete(model: SavedRecipe.self)
        try? modelContext.save()

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
