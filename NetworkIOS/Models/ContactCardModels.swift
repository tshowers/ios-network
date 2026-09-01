import Foundation

/// Mirrors the card DTO built by `toCardDto` in `todd-backend/functions/networkRoutes.js`.
/// Deliberately not the full `Contact` model from the web app — this is the
/// reduced, read-only shape `/network/cards` actually returns.
struct ContactCard: Codable, Identifiable, Equatable {
    let contactId: String
    let firstName: String
    let lastName: String
    let displayName: String
    let profession: String
    let company: CardCompany
    let city: String
    let state: String
    let relationship: String
    let category: String
    let source: String
    let important: Bool
    let lastContacted: String?
    let email: String
    let additionalEmailCount: Int
    let phone: String
    let additionalPhoneCount: Int
    let linkedInUrl: String

    var id: String { contactId }

    var locationLabel: String {
        [city, state].filter { !$0.isEmpty }.joined(separator: ", ")
    }

    /// Two-letter fallback shown when `company.logoUrl` is nil — deterministic
    /// so the same company always gets the same monogram/color.
    var monogram: String {
        let source = company.name.isEmpty ? displayName : company.name
        let letters = source
            .split(separator: " ")
            .compactMap { $0.first }
            .prefix(2)
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }

    // MARK: - Decoding

    /// Custom rather than synthesized: `[ContactCard]` decodes as one JSON
    /// array, so one card missing a field the client expects (e.g. an app
    /// build shipped ahead of, or behind, the deployed backend) would
    /// otherwise fail the *entire* page, not just that card. Fields added
    /// after the first cut of this endpoint (category/source/important/
    /// additionalEmailCount/additionalPhoneCount) are tolerant with sensible
    /// defaults; identity fields (contactId/firstName/lastName/displayName)
    /// still fail loudly, since a card with no id isn't a recoverable case.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        contactId = try container.decode(String.self, forKey: .contactId)
        firstName = try container.decode(String.self, forKey: .firstName)
        lastName = try container.decode(String.self, forKey: .lastName)
        displayName = try container.decode(String.self, forKey: .displayName)
        profession = try container.decodeIfPresent(String.self, forKey: .profession) ?? ""
        company = try container.decodeIfPresent(CardCompany.self, forKey: .company)
            ?? CardCompany(name: "", url: nil, logoUrl: nil)
        city = try container.decodeIfPresent(String.self, forKey: .city) ?? ""
        state = try container.decodeIfPresent(String.self, forKey: .state) ?? ""
        relationship = try container.decodeIfPresent(String.self, forKey: .relationship) ?? ""
        category = try container.decodeIfPresent(String.self, forKey: .category) ?? ""
        source = try container.decodeIfPresent(String.self, forKey: .source) ?? ""
        important = try container.decodeIfPresent(Bool.self, forKey: .important) ?? false
        lastContacted = try container.decodeIfPresent(String.self, forKey: .lastContacted)
        email = try container.decodeIfPresent(String.self, forKey: .email) ?? ""
        additionalEmailCount = try container.decodeIfPresent(Int.self, forKey: .additionalEmailCount) ?? 0
        phone = try container.decodeIfPresent(String.self, forKey: .phone) ?? ""
        additionalPhoneCount = try container.decodeIfPresent(Int.self, forKey: .additionalPhoneCount) ?? 0
        linkedInUrl = try container.decodeIfPresent(String.self, forKey: .linkedInUrl) ?? ""
    }
}

struct CardCompany: Codable, Equatable {
    let name: String
    let url: String?
    let logoUrl: String?
}

struct ContactCardPage: Codable {
    let cards: [ContactCard]
    let nextCursor: String?
}

struct ContactCardPageEnvelope: Codable {
    let success: Bool
    let data: ContactCardPage
}
