import XCTest
@testable import MemoryAisle2

/// Pins the "users keep getting signed out" fix.
///
/// Two original bugs, both of which signed users out without their consent:
///   1. `signIn` only stored the AccessToken (1-hour TTL) and never the
///      RefreshToken. Any subsequent `fetchUser` 401 fell through to
///      `clearSession()` — wiping the keychain.
///   2. **Any** `fetchUser` failure (network blip, Cognito 5xx, DNS hiccup)
///      was treated as token-expired and triggered the same wipe.
///
/// And one Apple-Sign-In bug: SIWA users were signed out on every cold
/// launch because `restoreSession` required a Cognito token they never have.
///
/// These tests pin all three fixes against a mocked Cognito endpoint so a
/// future refactor can't silently regress them.
@MainActor
final class CognitoAuthManagerTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        URLProtocol.registerClass(StubURLProtocol.self)
        StubURLProtocol.handler = nil
        clearTestKeychain()
        UserDefaults.standard.removeObject(forKey: "ma_apple_user_id")
        UserDefaults.standard.removeObject(forKey: "ma_email")
        UserDefaults.standard.removeObject(forKey: "ma_token")
        UserDefaults.standard.removeObject(forKey: "ma_name")
    }

    override func tearDown() async throws {
        URLProtocol.unregisterClass(StubURLProtocol.self)
        StubURLProtocol.handler = nil
        clearTestKeychain()
        UserDefaults.standard.removeObject(forKey: "ma_apple_user_id")
        UserDefaults.standard.removeObject(forKey: "ma_email")
        UserDefaults.standard.removeObject(forKey: "ma_token")
        UserDefaults.standard.removeObject(forKey: "ma_name")
        try await super.tearDown()
    }

    // MARK: - Apple Sign In persistence

    func test_restoreSession_withAppleMarker_signsInWithoutCognito() async {
        UserDefaults.standard.set("apple-user-123", forKey: "ma_apple_user_id")
        UserDefaults.standard.set("user@example.com", forKey: "ma_email")

        var didCallCognito = false
        StubURLProtocol.handler = { _ in
            didCallCognito = true
            return (200, Data())
        }

        let auth = CognitoAuthManager()
        await auth.restoreSession()

        XCTAssertTrue(auth.isSignedIn, "Apple session marker should be enough — no Cognito token needed")
        XCTAssertEqual(auth.email, "user@example.com")
        XCTAssertFalse(didCallCognito, "SIWA path should short-circuit before any Cognito request")
    }

    // MARK: - The "transient error wipes the keychain" regression

    func test_restoreSession_networkError_doesNotWipeKeychain() async {
        seedCognitoSession(token: "valid-access", refresh: "valid-refresh", email: "user@example.com")

        StubURLProtocol.handler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        let auth = CognitoAuthManager()
        await auth.restoreSession()

        XCTAssertTrue(
            auth.isSignedIn,
            "A network blip on launch must NOT sign the user out"
        )
        XCTAssertNotNil(
            readKeychain("ma_token"),
            "Keychain access token must survive a transient launch failure"
        )
        XCTAssertNotNil(
            readKeychain("ma_refresh"),
            "Keychain refresh token must survive a transient launch failure"
        )
    }

    func test_restoreSession_serverError_doesNotWipeKeychain() async {
        seedCognitoSession(token: "valid-access", refresh: "valid-refresh", email: "user@example.com")

        StubURLProtocol.handler = { _ in
            (502, Data("Bad Gateway".utf8))
        }

        let auth = CognitoAuthManager()
        await auth.restoreSession()

        XCTAssertTrue(auth.isSignedIn, "Cognito 5xx must NOT sign the user out")
        XCTAssertNotNil(readKeychain("ma_token"))
        XCTAssertNotNil(readKeychain("ma_refresh"))
    }

    // MARK: - Refresh-token flow

    func test_restoreSession_expiredAccessToken_refreshesAndStaysSignedIn() async {
        seedCognitoSession(token: "expired-access", refresh: "valid-refresh", email: "user@example.com")

        var requestCount = 0
        StubURLProtocol.handler = { request in
            requestCount += 1
            let target = request.value(forHTTPHeaderField: "X-Amz-Target") ?? ""
            let body = request.bodyForTest()

            // Call 1: GetUser with expired token → tokenExpired
            if target.hasSuffix("GetUser") {
                if requestCount == 1 {
                    let payload: [String: Any] = [
                        "__type": "NotAuthorizedException",
                        "message": "Access Token has expired"
                    ]
                    return (401, try JSONSerialization.data(withJSONObject: payload))
                }
                // Call 3: GetUser with refreshed token → 200
                let payload: [String: Any] = ["Username": "user-uuid-123"]
                return (200, try JSONSerialization.data(withJSONObject: payload))
            }

            // Call 2: REFRESH_TOKEN_AUTH → new access token
            if target.hasSuffix("InitiateAuth"), body.contains("REFRESH_TOKEN_AUTH") {
                let payload: [String: Any] = [
                    "AuthenticationResult": [
                        "AccessToken": "new-access-token"
                    ]
                ]
                return (200, try JSONSerialization.data(withJSONObject: payload))
            }

            return (500, Data())
        }

        let auth = CognitoAuthManager()
        await auth.restoreSession()

        XCTAssertTrue(auth.isSignedIn, "An expired access token with a valid refresh token must stay signed in")
        XCTAssertEqual(readKeychain("ma_token"), "new-access-token", "New access token must be persisted")
        XCTAssertNotNil(readKeychain("ma_refresh"), "Refresh token must remain")
    }

    func test_restoreSession_bothTokensExpired_signsOutCleanly() async {
        seedCognitoSession(token: "expired-access", refresh: "expired-refresh", email: "user@example.com")

        StubURLProtocol.handler = { _ in
            let payload: [String: Any] = [
                "__type": "NotAuthorizedException",
                "message": "Refresh Token has expired"
            ]
            return (401, try JSONSerialization.data(withJSONObject: payload))
        }

        let auth = CognitoAuthManager()
        await auth.restoreSession()

        XCTAssertFalse(auth.isSignedIn, "If both tokens are dead the session is genuinely over")
        XCTAssertNil(readKeychain("ma_token"), "Genuine sign-out should clear the keychain")
        XCTAssertNil(readKeychain("ma_refresh"))
    }

    // MARK: - signOut clears Apple markers

    func test_signOut_wipesAppleSessionMarkers() {
        UserDefaults.standard.set("apple-user-123", forKey: "ma_apple_user_id")
        UserDefaults.standard.set("Kevin", forKey: "ma_name")

        let auth = CognitoAuthManager()
        auth.signOut()

        XCTAssertNil(
            UserDefaults.standard.string(forKey: "ma_apple_user_id"),
            "signOut must drop the Apple marker, otherwise restoreSession would silently re-sign-in the just-signed-out user"
        )
        XCTAssertNil(UserDefaults.standard.string(forKey: "ma_name"))
    }

    // MARK: - Helpers

    private func seedCognitoSession(token: String, refresh: String, email: String) {
        writeKeychain("ma_email", email)
        writeKeychain("ma_token", token)
        writeKeychain("ma_refresh", refresh)
    }

    private func clearTestKeychain() {
        for key in ["ma_email", "ma_token", "ma_refresh"] {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: "com.sltrdigital.memoryaisle",
                kSecAttrAccount as String: key
            ]
            SecItemDelete(query as CFDictionary)
        }
    }

    private func writeKeychain(_ key: String, _ value: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.sltrdigital.memoryaisle",
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    private func readKeychain(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.sltrdigital.memoryaisle",
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

// MARK: - URL Protocol Stub

/// Minimal URLProtocol stub. `URLSession.shared` consults registered
/// protocol classes, so registering this class lets the tests intercept
/// every Cognito request without changing the manager's session
/// injection. The `handler` closure decides what to return for each
/// request, including throwing to simulate URLSession-level transport
/// failures (e.g. URLError(.notConnectedToInternet)).
final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (Int, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host?.contains("cognito-idp") == true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = StubURLProtocol.handler, let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        do {
            let (status, data) = try handler(request)
            let response = HTTPURLResponse(
                url: url,
                statusCode: status,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/x-amz-json-1.1"]
            )
            if let response {
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            }
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private extension URLRequest {
    /// `URLRequest.httpBody` is nil under URLProtocol stubbing because
    /// the stream gets consumed during transport setup. Read it back
    /// from the `httpBodyStream` so test handlers can inspect what was
    /// actually sent (used to distinguish REFRESH_TOKEN_AUTH from
    /// USER_PASSWORD_AUTH or InitiateAuth variants).
    func bodyForTest() -> String {
        if let data = httpBody, let body = String(data: data, encoding: .utf8) { return body }
        guard let stream = httpBodyStream else { return "" }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let bufferSize = 4096
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: bufferSize)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return String(data: data, encoding: .utf8) ?? ""
    }
}
