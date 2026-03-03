import SwiftUI

@main
struct KeyAtlasApp: App {
    @State private var authService = AuthService.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authService)
                .task {
                    await authService.restoreSession()
                }
                .preferredColorScheme(nil) // Respect system dark/light mode
        }
    }
}
