import Foundation
import UserNotifications
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class PushNotificationService: NSObject, Sendable {
    static let shared = PushNotificationService()

    private override init() {}

    func requestPermissionAndRegister() async {
        #if canImport(UIKit)
        do {
            let center = UNUserNotificationCenter.current()
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            guard granted else { return }
            UIApplication.shared.registerForRemoteNotifications()
        } catch {
            print("Push permission request failed", error)
        }
        #endif
    }

    func didRegister(deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        Task {
            try? KeychainService.save(token, for: .pushToken)
            await syncTokenIfPossible(token)
        }
    }

    func syncTokenIfPossible(_ token: String? = nil) async {
        guard KeychainService.load(.authToken) != nil else { return }
        let tokenValue = token ?? KeychainService.load(.pushToken)
        guard let tokenValue, !tokenValue.isEmpty else { return }

        struct Body: Codable, Hashable, Sendable {
            let token: String
            let platform: String
            let app_bundle_id: String?
            let app_version: String?
            let device_name: String?
        }

        let bundle = Bundle.main.bundleIdentifier
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String

        let body = Body(
            token: tokenValue,
            platform: "ios",
            app_bundle_id: bundle,
            app_version: version,
            device_name: nil
        )

        try? await APIClient.shared.requestVoid(.post, path: "/api/v1/push/register", body: body, authenticated: true)
    }

    func unregisterCurrentToken() async {
        guard let token = KeychainService.load(.pushToken), !token.isEmpty else { return }

        struct Body: Codable, Hashable, Sendable { let token: String }
        try? await APIClient.shared.requestVoid(.post, path: "/api/v1/push/unregister", body: Body(token: token), authenticated: true)
    }
}

#if canImport(UIKit)
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        PushNotificationService.shared.didRegister(deviceToken: deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("APNS registration failed", error)
    }
}
#endif
