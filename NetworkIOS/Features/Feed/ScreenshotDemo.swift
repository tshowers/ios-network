import Foundation

/// Debug-only: `-screenshotDemo N` opens Network's card feed on sample
/// contacts (fictional people), showing card N, for App Store screenshots of
/// the app in use (App Review 2.3.3) - the real feed, cards and insight UI,
/// no server calls. Always off in Release builds.
enum ScreenshotDemo {
    /// The card to show first (1-based), or nil when not in demo mode.
    static var startCard: Int? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-screenshotDemo") else { return nil }
        return index + 1 < arguments.count ? max(1, Int(arguments[index + 1]) ?? 1) : 1
        #else
        return nil
        #endif
    }

    static var cards: [ContactCard] {
        let daysAgo: (Int) -> String = { days in
            ISO8601DateFormatter().string(from: Date().addingTimeInterval(TimeInterval(-days * 86_400)))
        }
        let people: [[String: Any]] = [
            person("c1", "Jordan", "Ellis", "VP of Operations", "Harbor Freight Logistics", "Seattle", "WA", "Client",
                   daysAgo(41), "jordan.ellis@example.com", "(206) 555-0142", 12, 9,
                   "Jordan's renewal is coming up next month and you haven't talked in six weeks. A quick check-in on how the Q3 rollout went keeps the renewal warm."),
            person("c2", "Priya", "Raman", "Founder & CEO", "Lumen Dental Studio", "Portland", "OR", "Prospect",
                   daysAgo(18), "priya@example.com", "(503) 555-0187", 4, 3,
                   "Priya opened your last two emails and clicked the pricing link. She's comparing options now. A short note offering a 15-minute walkthrough fits the moment."),
            person("c3", "Marcus", "Bell", "Director of Partnerships", "Northwind Credit Union", "Tacoma", "WA", "Partner",
                   daysAgo(63), "mbell@example.com", "(253) 555-0119", 7, 11,
                   "It's been two months since you and Marcus co-hosted the small-business workshop. Suggest a second session for spring while it's still fresh."),
            person("c4", "Elena", "Torres", "Marketing Manager", "Cascade Outdoor Co.", "Bend", "OR", "Warm lead",
                   daysAgo(9), "elena.torres@example.com", "(541) 555-0133", 3, 2,
                   "Elena asked for a case study at last week's meetup. Send the Harbor Freight story while she remembers the conversation."),
            person("c5", "David", "Kim", "Owner", "Kim & Sons Construction", "Spokane", "WA", "Client",
                   daysAgo(120), "david@example.com", "(509) 555-0176", 15, 6,
                   "Four months of quiet from a long-time client. David referred two customers last year. A thank-you and a catch-up call could spark the next referral."),
            person("c6", "Aisha", "Grant", "Head of People", "Brightline Health", "Boise", "ID", "Prospect",
                   daysAgo(27), "agrant@example.com", "(208) 555-0158", 2, 4,
                   "Brightline just announced a new office. Congratulate Aisha and ask how onboarding is going for the new team."),
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: people),
              let cards = try? JSONDecoder().decode([ContactCard].self, from: data) else { return [] }
        return cards
    }

    private static func person(
        _ id: String, _ first: String, _ last: String, _ profession: String, _ company: String,
        _ city: String, _ state: String, _ relationship: String, _ lastContacted: String,
        _ email: String, _ phone: String, _ engagements: Int, _ interactions: Int, _ insight: String
    ) -> [String: Any] {
        [
            "contactId": id, "firstName": first, "middleName": "", "lastName": last,
            "displayName": "\(first) \(last)", "profession": profession,
            "company": ["name": company], "city": city, "state": state,
            "relationship": relationship, "category": "Business", "source": "Referral",
            "important": relationship == "Client", "lastContacted": lastContacted,
            "email": email, "phone": phone, "storedInsight": insight,
            "timezone": "America/Los_Angeles", "engagementsCount": engagements,
            "interactionsCount": interactions, "mutualConnections": engagements / 2,
            "contactValue": min(95, 40 + engagements * 3 + interactions * 2),
        ]
    }
}

extension CardFeedViewModel {
    /// The feed preloaded with the sample contacts - loadInitial, the total
    /// counter and insights all see data already present and skip the server.
    static func screenshotDemo(apiClient: NetworkAPIClient, startCard: Int) -> CardFeedViewModel {
        let viewModel = CardFeedViewModel(apiClient: apiClient, currentUserId: nil)
        viewModel.cards = ScreenshotDemo.cards
        viewModel.currentIndex = min(max(0, startCard - 1), max(0, viewModel.cards.count - 1))
        viewModel.setDemoTotal(48)
        return viewModel
    }
}
