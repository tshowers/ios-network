import SwiftUI
import TODDAuthKit

/// Gates the whole app behind sign-in + a fresh biometric check, same as
/// `pulse-ios` — Network shows real CRM data, so (unlike Maya, which works
/// signed out) there's no guest mode here at all.
struct RootView: View {
    @ObservedObject var authService: AuthService
    let apiClient: NetworkAPIClient

    var body: some View {
        Group {
            if authService.isLoading {
                ProgressView()
            } else if authService.currentUser == nil {
                SignInView(authService: authService)
            } else if !authService.sessionGate.isUnlocked {
                BiometricLockView(reason: "Unlock Network to view your contacts.") {
                    authService.sessionGate.markUnlocked()
                }
            } else {
                CardFeedView(viewModel: CardFeedViewModel(apiClient: apiClient, currentUserId: authService.userId))
            }
        }
    }
}
