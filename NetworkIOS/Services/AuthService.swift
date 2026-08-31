import Foundation
import FirebaseAuth
import FirebaseFirestore
import TODDAuthKit

/// Mirrors `frontend/src/app/services/auth.service.ts`'s `resolveAssignedTenantId`
/// (same `users/{uid}.companyId` lookup, falling back to the uid) — Network's cards
/// are real tenant-scoped CRM data, same as Maya's workspace context, so this follows
/// `maya-ios`'s `AuthService` rather than `pulse-ios`'s simpler uid-only version.
///
/// Sign-in is Sign in with Apple only (`TODDAuthKit.SignInWithAppleButtonView`).
/// `sessionGate` (also from `TODDAuthKit`) gates a silently-restored session behind a
/// fresh biometric check before any contact data loads — this app is read-only, but a
/// stranger picking up an unlocked phone shouldn't get a free scroll through someone's
/// CRM.
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
            Task { await self.refreshTenantId() }
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

    var errorDescription: String? {
        switch self {
        case .notSignedIn:
            return "Sign in to load your network."
        }
    }
}
