import SwiftUI
import FirebaseCore
import TODDAuthKit

@main
struct NetworkIOSApp: App {
    @StateObject private var authService = AuthService()
    private let apiClient: NetworkAPIClient

    init() {
        FirebaseApp.configure()

        let config = AppConfig.fromBundle()
        let authService = AuthService()
        _authService = StateObject(wrappedValue: authService)
        self.apiClient = NetworkAPIClient(config: config, authService: authService)
    }

    var body: some Scene {
        WindowGroup {
            RootView(authService: authService, apiClient: apiClient)
                // Google Sign-In's OAuth flow redirects back into the app
                // through the URL scheme registered in Info.plist; the SDK
                // needs to see that URL to complete the sign-in it started.
                .onOpenURL { url in
                    _ = GoogleSignInHelper.handle(url)
                }
        }
    }
}
