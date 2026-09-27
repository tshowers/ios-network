import Foundation

/// Mirrors the JSON shapes `appStoreRoutes.js` sends back from
/// `POST /api/app-store/link` and `GET /api/app-store/entitlement/:product`.
struct AppStoreLinkRequest: Encodable {
    let appAccountToken: String
    let productKey: String
}

struct AppStoreEntitlementRecord: Codable {
    let productId: String
    let originalTransactionId: String
    let status: String
    let expiresDate: Double?
}

struct AppStoreEntitlement: Codable {
    let active: Bool
    let records: [AppStoreEntitlementRecord]
}

struct AppStoreEntitlementEnvelope: Codable {
    let success: Bool
    let entitlement: AppStoreEntitlement
}
