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
