import Foundation

struct AppConfig {
    let apiBaseURL: URL
    /// The shared static key checked server-side as `TALIFERRO_TECH` — required by
    /// `/email-drafting/draft` (same gate the web Composer/Catalyst goes through).
    /// NOT used for `/network/cards`, which verifies a real Firebase ID token instead.
    let apiKey: String

    static func fromBundle(bundle: Bundle = .main) -> AppConfig {
        let baseURLString = bundle.object(forInfoDictionaryKey: "NETWORK_API_BASE_URL") as? String ?? ""
        let apiKey = bundle.object(forInfoDictionaryKey: "NETWORK_API_KEY") as? String ?? ""

        guard let apiBaseURL = URL(string: baseURLString) else {
            fatalError("Missing NETWORK_API_BASE_URL in app configuration.")
        }

        return AppConfig(apiBaseURL: apiBaseURL, apiKey: apiKey)
    }
}
