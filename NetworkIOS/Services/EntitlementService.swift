import Combine
import Foundation
import StoreKit
import TODDEntitlementKit

/// Wraps TODDEntitlementKit the same way AuthService wraps TODDAuthKit's
/// HostedLogin: the kit itself stays stateless, this is the app-level
/// ObservableObject RootView actually observes.
///
/// Until Network's App Store billing toggle flips server-side
/// (`APP_STORE_BILLING_ENABLED_NETWORK`, see appStoreConfig.js),
/// `networkEntitlement.service.js` keeps answering entitlement checks from
/// Stripe, not this. This service exists so the purchase flow can be built
/// and tested end-to-end against Apple's sandbox before that cutover
/// happens, not because it's load-bearing yet.
@MainActor
final class EntitlementService: ObservableObject {
    @Published private(set) var isEntitled = false
    @Published private(set) var isLoadingEntitlement = true
    @Published private(set) var products: [Product] = []
    @Published private(set) var isPurchasing = false
    @Published var errorMessage: String?

    private let apiClient: NetworkAPIClient
    private let authService: AuthService
    private let config: AppConfig
    private var transactionObserverTask: Task<Void, Never>?
    private var authSubscription: AnyCancellable?
    private var lastSeenUserId: String?

    init(apiClient: NetworkAPIClient, authService: AuthService, config: AppConfig) {
        self.apiClient = apiClient
        self.authService = authService
        self.config = config
        self.lastSeenUserId = authService.userId

        transactionObserverTask = TransactionObserver.start { [weak self] _ in
            // A transaction updated outside an explicit purchase() call on this
            // device (background renewal, Ask to Buy, another device) - the
            // backend learns the real state from Apple's own Server
            // Notification independently, so all this needs to do is refresh
            // what this device currently believes.
            await self?.refreshEntitlement()
        }

        // Whichever button a sign-out happens from (RootView's own, or
        // CardFeedView's), and whichever account signs in next, this needs
        // to reset - otherwise the next tenant's RootView render could
        // reuse the previous tenant's stale isEntitled instead of running a
        // fresh check.
        authSubscription = authService.$currentUser
            .map { $0?.uid }
            .removeDuplicates()
            .sink { [weak self] uid in
                guard let self, uid != self.lastSeenUserId else { return }
                self.lastSeenUserId = uid
                self.reset()
            }
    }

    deinit {
        transactionObserverTask?.cancel()
    }

    func reset() {
        isEntitled = false
        isLoadingEntitlement = true
        products = []
        errorMessage = nil
    }

    private var configuredProductIds: [String] {
        [config.networkProductId, config.networkContactsPackProductId].filter { !$0.isEmpty }
    }

    func loadProducts() async {
        guard !configuredProductIds.isEmpty else {
            errorMessage = "Network's App Store subscription isn't configured yet."
            return
        }

        do {
            products = try await PurchaseManager.fetchProducts(productIds: configuredProductIds)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshEntitlement() async {
        isLoadingEntitlement = true
        defer { isLoadingEntitlement = false }

        do {
            isEntitled = try await apiClient.fetchAppStoreEntitlement().active
        } catch {
            // Network hiccup fetching entitlement shouldn't read as "not
            // entitled" and boot a paying subscriber to the paywall - leave
            // isEntitled at its last known value.
            errorMessage = error.localizedDescription
        }
    }

    func purchase(_ product: Product) async {
        guard let uid = authService.userId else { return }
        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }

        do {
            let token = Self.appAccountToken(for: uid)
            // Link before purchasing - see the doc comment on
            // NetworkAPIClient.linkAppStorePurchase for why the order matters.
            try await apiClient.linkAppStorePurchase(appAccountToken: token.uuidString)
            try await PurchaseManager.purchase(product, appAccountToken: token)
            await refreshEntitlement()
        } catch PurchaseError.userCancelled {
            // Not an error worth surfacing.
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func restorePurchases() async {
        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }

        do {
            try await PurchaseManager.restorePurchases()
            await refreshEntitlement()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// One stable appAccountToken per signed-in TODD user, reused across
    /// every purchase they make in this app (base subscription, contacts
    /// pack add-on, ...) so they all link back to the same tenant.
    private static func appAccountToken(for uid: String) -> UUID {
        let key = "network.appAccountToken.\(uid)"
        if let stored = UserDefaults.standard.string(forKey: key), let uuid = UUID(uuidString: stored) {
            return uuid
        }
        let generated = UUID()
        UserDefaults.standard.set(generated.uuidString, forKey: key)
        return generated
    }
}
