import Foundation

struct AppConfig {
    let apiBaseURL: URL
    /// The shared static key checked server-side as `TALIFERRO_TECH` — required by
    /// `/email-drafting/draft` (same gate the web Composer/Catalyst goes through).
    /// NOT used for `/network/cards`, which verifies a real Firebase ID token instead.
    let apiKey: String
    /// App Store Connect product identifiers for Network's subscription and its
    /// stacked "extra 1,000 contacts" add-on (see networkEntitlement.service.js's
    /// APP_STORE_PRODUCT_ID_NETWORK / _NETWORK_CONTACTS_PACK). Empty until those
    /// products actually exist in App Store Connect — EntitlementService treats an
    /// empty id as "not configured yet" rather than crashing, since (unlike
    /// apiBaseURL) the app needs to keep working before this billing cutover ships.
    let networkProductId: String
    let networkContactsPackProductId: String

    static func fromBundle(bundle: Bundle = .main) -> AppConfig {
        let baseURLString = bundle.object(forInfoDictionaryKey: "NETWORK_API_BASE_URL") as? String ?? ""
        let apiKey = bundle.object(forInfoDictionaryKey: "NETWORK_API_KEY") as? String ?? ""
        let networkProductId = bundle.object(forInfoDictionaryKey: "NETWORK_APP_STORE_PRODUCT_ID") as? String ?? ""
        let networkContactsPackProductId = bundle.object(forInfoDictionaryKey: "NETWORK_APP_STORE_CONTACTS_PACK_PRODUCT_ID") as? String ?? ""

        guard let apiBaseURL = URL(string: baseURLString) else {
            fatalError("Missing NETWORK_API_BASE_URL in app configuration.")
        }

        return AppConfig(
            apiBaseURL: apiBaseURL,
            apiKey: apiKey,
            networkProductId: networkProductId,
            networkContactsPackProductId: networkContactsPackProductId
        )
    }
}
