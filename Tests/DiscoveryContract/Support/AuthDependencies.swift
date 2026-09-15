import Foundation
// Only peripheral push/OAuth dependencies are replaced. AuthService itself is a
// byte-for-byte production copy, using memory-only Keychain and intercepted HTTP.
final class PushNotificationService: Sendable {
    static let shared = PushNotificationService()
    func syncTokenIfPossible() async {}
    func unregisterCurrentToken() async {}
}
struct OAuthResult: Sendable {
    let token: String
    let userId: String
    let username: String
    let role: String
    let avatar: String?
}
