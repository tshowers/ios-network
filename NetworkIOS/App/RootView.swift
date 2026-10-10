import SwiftUI
import TODDAuthKit
import TODDAwardsKit

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
    @ObservedObject var awardsService: AwardsService

    init(authService: AuthService, entitlementService: EntitlementService, apiClient: NetworkAPIClient, awardsService: AwardsService) {
        self.authService = authService
        self.entitlementService = entitlementService
        self.sessionGate = authService.sessionGate
        self.apiClient = apiClient
        self.awardsService = awardsService
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
                MainTabView(authService: authService, awardsService: awardsService, apiClient: apiClient)
                    // A different account gets a fresh store.
                    .id(authService.userId)
            }
        }
        // Awards live on the account, not the device: pull them on sign-in
        // and at launch so an award earned on the iPad shows (and isn't
        // re-celebrated) on the iPhone.
        .onChange(of: authService.userId) { oldValue, newValue in
            if oldValue == nil, newValue != nil {
                Task { await awardsService.sync() }
            }
            // Signed out (or account deleted): remove contacts saved on the device.
            if oldValue != nil, newValue == nil {
                ContactStore.clearAllCaches()
            }
        }
        .task {
            if authService.userId != nil { await awardsService.sync() }
        }
        .fullScreenCover(item: Binding(
            get: { awardsService.pendingUnlock },
            set: { newValue in if newValue == nil { awardsService.dismissCurrentUnlock() } }
        )) { award in
            AwardUnlockView(
                award: award,
                appName: "Network",
                unlockedCount: awardsService.unlockedCount,
                totalCount: awardsService.totalCount,
                onContinue: { awardsService.dismissCurrentUnlock() }
            )
        }
    }

    private func signOut() {
        try? authService.signOut()
    }
}
