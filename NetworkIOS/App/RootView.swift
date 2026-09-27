import SwiftUI
import TODDAuthKit

/// Gates the whole app behind sign-in + a fresh biometric check, same as
/// `pulse-ios` — Network shows real CRM data, so (unlike Maya, which works
/// signed out) there's no guest mode here at all.
struct RootView: View {
    @ObservedObject var authService: AuthService
    @ObservedObject var entitlementService: EntitlementService
    /// Observed directly (as pulse-ios does): `sessionGate` is its own
    /// ObservableObject, so observing only `authService` never redraws this
    /// view when Face ID succeeds - the lock screen stayed up after the
    /// green checkmark.
    @ObservedObject private var sessionGate: SessionUnlockGate
    let apiClient: NetworkAPIClient

    init(authService: AuthService, entitlementService: EntitlementService, apiClient: NetworkAPIClient) {
        self.authService = authService
        self.entitlementService = entitlementService
        self.sessionGate = authService.sessionGate
        self.apiClient = apiClient
    }

    var body: some View {
        Group {
            if authService.isLoading {
                ProgressView()
            } else if authService.currentUser == nil {
                // Pre-sign-in wizard (name, role, company, goals, timezone)
                // ending in sign-in; returning users skip to SignInView
                // from inside it.
                OnboardingWizardView(authService: authService)
            } else if !sessionGate.isUnlocked {
                BiometricLockView(reason: "Unlock Network to view your contacts.") {
                    sessionGate.markUnlocked()
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
