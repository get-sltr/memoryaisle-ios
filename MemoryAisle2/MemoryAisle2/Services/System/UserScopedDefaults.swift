import CryptoKit
import Foundation

/// UserDefaults wrapper that scopes a small allow-list of keys to the
/// currently signed-in user. Without this, a key like `ma_avatar` or
/// `medicationStartDate` is device-scoped and survives account changes
/// on the same device — meaning User B would inherit User A's avatar
/// and medication dates when signing in. By routing those specific
/// keys through a per-user hashed suffix, each user's values live
/// under their own key in UserDefaults and never collide.
///
/// Keys NOT in `userScopedKeys` pass straight through to
/// `UserDefaults.standard` unchanged. Anything that's genuinely
/// device-scoped (welcome-seen flag, install marker, reviewer flag)
/// should stay out of this allow-list on purpose.
enum UserScopedDefaults {

    /// Explicit allow-list of keys that carry per-user data. Everything
    /// else reads/writes the plain key, so device-level settings don't
    /// accidentally get user-scoped.
    private static let userScopedKeys: Set<String> = [
        "ma_avatar",
        "medicationStartDate",
        "journeyStartDate"
    ]

    // MARK: - Scoped-key resolution

    private static func scopedKey(_ base: String) -> String {
        guard userScopedKeys.contains(base),
              let userId = UserDataContainer.currentIdentifier() else {
            return base
        }
        return "\(base)__\(hash(userId))"
    }

    private static func hash(_ input: String) -> String {
        let digest = SHA256.hash(data: Data(input.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return String(hex.prefix(16))
    }

    // MARK: - Read / write

    static func set(_ value: Any?, forKey key: String) {
        UserDefaults.standard.set(value, forKey: scopedKey(key))
    }

    static func data(forKey key: String) -> Data? {
        UserDefaults.standard.data(forKey: scopedKey(key))
    }

    static func object(forKey key: String) -> Any? {
        UserDefaults.standard.object(forKey: scopedKey(key))
    }

    static func removeObject(forKey key: String) {
        UserDefaults.standard.removeObject(forKey: scopedKey(key))
    }
}
