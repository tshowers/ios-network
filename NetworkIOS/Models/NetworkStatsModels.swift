import Foundation

/// Mirrors the DTO built by `GET /network/stats` in `networkRoutes.js`, which
/// itself mirrors `home.component.ts`'s `getDashboardCounts()`.
struct NetworkStats: Codable {
    let totalContacts: Int
    let contactsAddedToday: Int
    let importantContacts: Int
    let contactsWithEmails: Int
    let contactsWithLinkedIn: Int
    let contactsWithSocialMedia: Int
    let staleContacts: Int
    let contactsNeedingFollowUp: Int
    let birthdaysThisMonth: Int
    let contactsByStatus: [String: Int]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        totalContacts = try container.decodeIfPresent(Int.self, forKey: .totalContacts) ?? 0
        contactsAddedToday = try container.decodeIfPresent(Int.self, forKey: .contactsAddedToday) ?? 0
        importantContacts = try container.decodeIfPresent(Int.self, forKey: .importantContacts) ?? 0
        contactsWithEmails = try container.decodeIfPresent(Int.self, forKey: .contactsWithEmails) ?? 0
        contactsWithLinkedIn = try container.decodeIfPresent(Int.self, forKey: .contactsWithLinkedIn) ?? 0
        contactsWithSocialMedia = try container.decodeIfPresent(Int.self, forKey: .contactsWithSocialMedia) ?? 0
        staleContacts = try container.decodeIfPresent(Int.self, forKey: .staleContacts) ?? 0
        contactsNeedingFollowUp = try container.decodeIfPresent(Int.self, forKey: .contactsNeedingFollowUp) ?? 0
        birthdaysThisMonth = try container.decodeIfPresent(Int.self, forKey: .birthdaysThisMonth) ?? 0
        contactsByStatus = try container.decodeIfPresent([String: Int].self, forKey: .contactsByStatus) ?? [:]
    }
}

struct NetworkStatsEnvelope: Codable {
    let success: Bool
    let data: NetworkStats
}
