import Foundation

enum NetworkAPIError: LocalizedError {
    case notAuthenticated
    case invalidResponse
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Sign in to load your network."
        case .invalidResponse:
            return "The server response could not be understood."
        case .httpError(let code):
            return "The server returned HTTP \(code)."
        }
    }
}

/// Talks to three existing `todd-backend` endpoints — none of this drafting or
/// sending logic is new, it's the same paths TODD's web app already uses. The two
/// families use genuinely different auth, which is why this isn't one shared
/// "authorized request" helper:
///   - `/network/cards` (new, added alongside this app) — a real, verified Firebase
///     ID token (`requireVerifiedUser` in `networkRoutes.js`).
///   - `/email-drafting/draft` and `/send-email` — the same shared static
///     `TALIFERRO_TECH` key every TODD frontend already ships (`validateApiKey`
///     server-side for the draft endpoint; `/send-email` itself checks nothing at
///     all beyond that, same as SayIt's `EmailService` calling it directly).
final class NetworkAPIClient {
    private let config: AppConfig
    private let authService: AuthService
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(config: AppConfig, authService: AuthService) {
        self.config = config
        self.authService = authService
    }

    func fetchCards(cursor: String? = nil, query: String? = nil, relationship: String? = nil) async throws -> ContactCardPage {
        var components = URLComponents(url: config.apiBaseURL.appending(path: "network/cards"), resolvingAgainstBaseURL: false)
        var items: [URLQueryItem] = []
        if let cursor { items.append(URLQueryItem(name: "cursor", value: cursor)) }
        if let query, !query.isEmpty { items.append(URLQueryItem(name: "query", value: query)) }
        if let relationship, !relationship.isEmpty { items.append(URLQueryItem(name: "relationship", value: relationship)) }
        components?.queryItems = items.isEmpty ? nil : items

        guard let url = components?.url else { throw NetworkAPIError.invalidResponse }

        let idToken = try await authService.freshIdToken()
        let data = try await request(method: "GET", url: url, authorization: "Bearer \(idToken)")
        let envelope = try decoder.decode(ContactCardPageEnvelope.self, from: data)
        return envelope.data
    }

    func fetchStats() async throws -> NetworkStats {
        let url = config.apiBaseURL.appending(path: "network/stats")
        let idToken = try await authService.freshIdToken()
        let data = try await request(method: "GET", url: url, authorization: "Bearer \(idToken)")
        let envelope = try decoder.decode(NetworkStatsEnvelope.self, from: data)
        return envelope.data
    }

    func draftEmail(for card: ContactCard) async throws -> DraftEmailResponse {
        guard let tenantId = await authService.tenantId else { throw NetworkAPIError.notAuthenticated }

        let payload = DraftEmailRequest(
            tenantId: tenantId,
            selectedContact: .init(
                id: card.contactId,
                firstName: card.firstName,
                lastName: card.lastName,
                email: card.email,
                profession: card.profession,
                company: .init(name: card.company.name),
                relationship: card.relationship,
                lastContacted: card.lastContacted
            )
        )

        let url = config.apiBaseURL.appending(path: "email-drafting/draft")
        let data = try await request(
            method: "POST",
            url: url,
            authorization: "Bearer \(config.apiKey)",
            body: try encoder.encode(payload)
        )
        let envelope = try decoder.decode(DraftEmailEnvelope.self, from: data)
        return envelope.data
    }

    func sendEmail(to recipient: String, subject: String, html: String) async throws {
        guard let tenantId = await authService.tenantId else { throw NetworkAPIError.notAuthenticated }

        let payload = SendEmailRequest(to: recipient, subject: subject, html: html, tenantId: tenantId)
        let url = config.apiBaseURL.appending(path: "send-email")
        _ = try await request(
            method: "POST",
            url: url,
            authorization: "Bearer \(config.apiKey)",
            body: try encoder.encode(payload)
        )
    }

    /// Lazy, per-card call (never batched across a whole page — this is a live
    /// OpenAI call, not something to fire off for every card in a fetched page).
    /// `CardFeedViewModel` calls this only for whichever card is currently on
    /// screen.
    func fetchInsight(for card: ContactCard) async throws -> String {
        let payload = ContactInsightRequest(profile: .init(
            firstName: card.firstName,
            lastName: card.lastName,
            profession: card.profession,
            companyName: card.company.name,
            relationship: card.relationship,
            lastContacted: card.lastContacted
        ))

        let url = config.apiBaseURL.appending(path: "contact-insight")
        let data = try await request(
            method: "POST",
            url: url,
            authorization: "Bearer \(config.apiKey)",
            body: try encoder.encode(payload)
        )
        return try decoder.decode(ContactInsightResponse.self, from: data).response
    }

    // MARK: - Request building

    private func request(method: String, url: URL, authorization: String, body: Data? = nil) async throws -> Data {
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(authorization, forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkAPIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkAPIError.httpError(httpResponse.statusCode)
        }

        return data
    }
}
