import CryptoKit
import Foundation

@Observable
final class CognitoAuthManager {
    private(set) var isSignedIn = false
    private(set) var isLoading = false
    private(set) var userId: String?
    private(set) var email: String?
    private(set) var accessToken: String?
    private(set) var error: String?

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

    func signOut() {
        isSignedIn = false
        accessToken = nil
        userId = nil
        email = nil
        clearSession()
    }

    // MARK: - Restore Session

    func restoreSession() async {
        guard let savedEmail = UserDefaults.standard.string(forKey: "ma_email"),
              let savedToken = UserDefaults.standard.string(forKey: "ma_token") else { return }

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
        var request = URLRequest(url: URL(string: baseURL)!)
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

    // MARK: - Session Persistence

    private func saveSession(email: String?, token: String?) {
        UserDefaults.standard.set(email, forKey: "ma_email")
        UserDefaults.standard.set(token, forKey: "ma_token")
    }

    private func clearSession() {
        UserDefaults.standard.removeObject(forKey: "ma_email")
        UserDefaults.standard.removeObject(forKey: "ma_token")
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
