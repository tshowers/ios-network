import Foundation
import FirebaseAuth
import FirebaseFirestore
import TODDAuthKit

/// Mirrors `frontend/src/app/services/auth.service.ts`'s `resolveAssignedTenantId`
/// (same `users/{uid}.companyId` lookup, falling back to the uid) — Network's cards
/// are real tenant-scoped CRM data, same as Maya's workspace context, so this follows
/// `maya-ios`'s `AuthService` rather than `pulse-ios`'s simpler uid-only version.
///
/// Sign-in is native Apple/Google (`TODDAuthKit.SignInWithAppleButtonView` /
/// `SignInWithGoogleButtonView`), not the web-redirect HostedLogin flow removed
/// 2026-09-20 - see docs/app-store-exclusive-billing-plan.md's "Native sign-in"
/// section. `sessionGate` (also from `TODDAuthKit`) gates a silently-restored
/// session behind a fresh biometric check before any contact data loads — this
/// app is read-only, but a stranger picking up an unlocked phone shouldn't get
/// a free scroll through someone's CRM.
@MainActor
final class AuthService: ObservableObject {
    @Published private(set) var currentUser: User?
    @Published private(set) var isLoading = true
    @Published private(set) var tenantId: String?

    let sessionGate = SessionUnlockGate()
    private var handle: AuthStateDidChangeListenerHandle?
    private let firestore = Firestore.firestore()

    init() {
        handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            self.currentUser = user
            self.isLoading = false
            self.sessionGate.handleAuthStateChange(hasUser: user != nil)
            Task {
                await self.refreshTenantId()
                // Retries a wizard save that failed on a previous launch.
                if user != nil { await self.submitOnboardingProfileIfNeeded() }
            }
        }
    }

    deinit {
        if let handle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    var userId: String? { currentUser?.uid }
    var userEmail: String? { currentUser?.email }

    func signOut() throws {
        try Auth.auth().signOut()
        tenantId = nil
    }

    /// Fresh Firebase ID token for the `Authorization: Bearer` header `NetworkAPIClient`
    /// sends — `/network/cards` verifies this server-side rather than trusting a plain
    /// tenant/user-id header (see the comment on `requireVerifiedUser` in
    /// `todd-backend/functions/networkRoutes.js` for why this endpoint specifically
    /// needed a stronger boundary than the rest of the backend uses).
    func freshIdToken() async throws -> String {
        guard let user = currentUser else {
            throw AuthServiceError.notSignedIn
        }
        return try await user.getIDToken()
    }

    /// Calls the backend's get-or-create tenant/contact endpoint
    /// (`POST /api/mobile/auth/bootstrap`, `mobileAuthRoutes.js`) right after a
    /// fresh native sign-in. Server-side rather than direct client Firestore
    /// writes (the pattern the web app uses) so provisioning logic lives in one
    /// place - see docs/app-store-exclusive-billing-plan.md's "Native sign-in"
    /// section for why. Updates `tenantId` with the authoritative result.
    func bootstrapTenant() async throws {
        let idToken = try await freshIdToken()
        let url = AppConfig.fromBundle().apiBaseURL.appending(path: "mobile/auth/bootstrap")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw AuthServiceError.bootstrapFailed
        }

        let decoded = try JSONDecoder().decode(BootstrapResponse.self, from: data)
        tenantId = decoded.tenantId
        await submitOnboardingProfileIfNeeded()
    }

    /// Saves the answers from the pre-sign-in `OnboardingWizardView` to the
    /// user's TODD profile (`POST /api/onboarding/profile`, which only fills
    /// blank fields - an existing profile is never overwritten). Best-effort:
    /// a failure never blocks getting into the app, and the draft stays
    /// stored so the next launch retries it.
    func submitOnboardingProfileIfNeeded() async {
        let draft = OnboardingProfileDraft.load()
        guard draft.isReadyToSubmit, currentUser != nil else { return }

        do {
            let idToken = try await freshIdToken()
            var request = URLRequest(url: AppConfig.fromBundle().apiBaseURL.appending(path: "onboarding/profile"))
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            request.httpBody = try JSONSerialization.data(withJSONObject: draft.requestBody)

            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
                OnboardingProfileDraft.clear()
            }
        } catch {
            // Kept for the next launch's retry.
        }
    }

    private func refreshTenantId() async {
        guard let uid = currentUser?.uid else {
            tenantId = nil
            return
        }

        do {
            let snapshot = try await firestore.collection("users").document(uid).getDocument()
            let companyId = (snapshot.data()?["companyId"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            tenantId = (companyId?.isEmpty == false ? companyId : nil) ?? uid
        } catch {
            tenantId = uid
        }
    }
}

enum AuthServiceError: LocalizedError {
    case notSignedIn
    case bootstrapFailed

    var errorDescription: String? {
        switch self {
        case .notSignedIn:
            return "Sign in to load your network."
        case .bootstrapFailed:
            return "Unable to set up your account. Please try again."
        }
    }
}

private struct BootstrapResponse: Decodable {
    let success: Bool
    let tenantId: String
    let isNewTenant: Bool
}
