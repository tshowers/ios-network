import SwiftUI
import FirebaseAuth
import FirebaseCore
import TODDAuthKit
import TODDAwardsKit

@main
struct NetworkIOSApp: App {
    @StateObject private var authService = AuthService()
    @StateObject private var entitlementService: EntitlementService
    @StateObject private var awardsService: AwardsService
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
        _awardsService = StateObject(wrappedValue: NetworkAwards.makeService(authService: authService))
        let apiClient = NetworkAPIClient(config: config, authService: authService)
        self.apiClient = apiClient
        _entitlementService = StateObject(wrappedValue: EntitlementService(
            apiClient: apiClient,
            authService: authService,
            config: config
        ))
    }

    var body: some Scene {
        WindowGroup {
            if PaywallScreenshot.current != nil {
                PaywallView(entitlementService: entitlementService, onSignOut: {})
            } else {
                RootView(authService: authService, entitlementService: entitlementService, apiClient: apiClient, awardsService: awardsService)
                    .onOpenURL { url in
                        _ = GoogleSignInHelper.handle(url)
                    }
            }
        }
    }
}
