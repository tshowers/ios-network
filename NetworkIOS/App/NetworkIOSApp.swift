import SwiftUI
import FirebaseAuth
import FirebaseCore
import TODDAuthKit

@main
struct NetworkIOSApp: App {
    @StateObject private var authService = AuthService()
    private let apiClient: NetworkAPIClient

    init() {
        FirebaseApp.configure()

        #if DEBUG
        // Firebase silently restores a signed-in session across launches,
        // which then needs a fresh biometric check (BiometricLockView) - on
        // the Simulator, evaluatePolicy's system Face ID sheet swallows
        // touches, so there's no way to satisfy or skip that check. Signing
        // out here forces every debug launch to start at SignInView instead,
        // side-stepping the Simulator-only dead end entirely. #if DEBUG
        // means this can't ship in a Release build by construction.
        try? Auth.auth().signOut()
        #endif

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
