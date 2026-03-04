import SwiftUI

@main
struct KeyAtlasApp: App {
    @State private var authService = AuthService.shared
    #if canImport(UIKit)
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authService)
                .task {
                    await authService.restoreSession()
                    await PushNotificationService.shared.requestPermissionAndRegister()
                }
                .preferredColorScheme(nil) // Respect system dark/light mode
        }
    }
}
