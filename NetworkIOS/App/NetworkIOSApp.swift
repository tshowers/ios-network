import SwiftUI
import FirebaseCore

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
        }
    }
}
