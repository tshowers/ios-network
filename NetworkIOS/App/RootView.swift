import SwiftUI
import TODDAuthKit

/// Gates the whole app behind sign-in + a fresh biometric check, same as
/// `pulse-ios` — Network shows real CRM data, so (unlike Maya, which works
/// signed out) there's no guest mode here at all.
struct RootView: View {
    @ObservedObject var authService: AuthService
    @ObservedObject var entitlementService: EntitlementService
    let apiClient: NetworkAPIClient

    var body: some View {
        Group {
            if authService.isLoading {
                ProgressView()
            } else if authService.currentUser == nil {
                // Pre-sign-in wizard (name, role, company, goals, timezone)
                // ending in sign-in; returning users skip to SignInView
                // from inside it.
                OnboardingWizardView(authService: authService)
            } else if !authService.sessionGate.isUnlocked {
                BiometricLockView(reason: "Unlock Network to view your contacts.") {
                    authService.sessionGate.markUnlocked()
                }
            } else if entitlementService.isLoadingEntitlement {
                ProgressView()
                    .task { await entitlementService.refreshEntitlement() }
            } else if !entitlementService.isEntitled {
                PaywallView(entitlementService: entitlementService, onSignOut: signOut)
            } else {
                CardFeedView(
                    viewModel: CardFeedViewModel(apiClient: apiClient, currentUserId: authService.userId),
                    authService: authService
                )
            }
        }
    }

    private func signOut() {
        try? authService.signOut()
    }
}
