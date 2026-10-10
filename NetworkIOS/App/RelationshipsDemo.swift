import Foundation

/// Debug-only: `-relationshipsDemo` opens the signed-in tabs on fictional
/// sample contacts with no sign-in and no server calls, for checking the
/// screens and taking App Store screenshots (App Review 2.3.3). Saving
/// changes in demo mode fails, since nothing is reachable. Always off in
/// Release builds.
enum RelationshipsDemo {
    static var isOn: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-relationshipsDemo")
        #else
        return false
        #endif
    }

    /// `-relationshipsDemo d1` opens that contact; `-relationshipsDemo new`
    /// opens the editor.
    static var startTarget: String? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-relationshipsDemo"), index + 1 < arguments.count else { return nil }
        let value = arguments[index + 1]
        return value.hasPrefix("-") ? nil : value
        #else
        return nil
        #endif
    }

    static let details: [ContactDetail] = {
        let iso = ISO8601DateFormatter()
        func daysAgo(_ days: Int) -> String { iso.string(from: Date().addingTimeInterval(TimeInterval(-days * 86_400))) }

        func contact(
            _ id: String, _ first: String, _ last: String, _ title: String, _ company: String,
            status: String, stage: String, lastContacted: Int?, added: Int, city: String, state: String,
            email: String, phone: String, notes: [(String, String, Int)] = [], capabilities: [String] = [],
            publicInfo: String = "", insight: String = "", important: Bool = false
        ) -> [String: Any] {
            [
                "contactId": id, "firstName": first, "lastName": last, "displayName": "\(first) \(last)",
                "profession": title, "status": status, "emailStage": stage, "important": important,
                "category": "", "profileTypes": [String](),
                "company": [
                    "name": company, "url": NSNull(), "logoUrl": NSNull(), "publicInfo": publicInfo,
                    "dba": "", "numberOfEmployees": "", "sicCode": "", "capabilities": capabilities,
                    "addresses": [[String: Any]](),
                ],
                "addresses": [["addressType": "Office", "streetAddress": "", "city": city, "state": state, "zip": "", "county": "", "country": ""]],
                "emailAddresses": [["emailAddress": email, "emailAddressType": "Work"]],
                "phoneNumbers": [["phoneNumber": phone, "phoneNumberType": "Mobile"]],
                "notes": notes.enumerated().map { index, note in
                    ["noteId": "\(id)-n\(index)", "subject": note.0, "body": note.1, "lastUpdated": daysAgo(note.2)]
                },
                "storedInsight": insight,
                "recentInteractions": lastContacted.map { [["type": "call", "date": daysAgo($0), "duration": 12, "notes": ""]] } ?? [],
                "interactionsCount": lastContacted == nil ? 0 : 6,
                "lastContacted": lastContacted.map(daysAgo) ?? NSNull(),
                "dateAdded": daysAgo(added),
                "lastUpdated": daysAgo(min(added, lastContacted ?? added)),
            ]
        }

        let people: [[String: Any]] = [
            contact("d1", "Jordan", "Ellis", "VP of Operations", "Harbor Freight Logistics", status: "Negotiation", stage: "meeting_push",
                    lastContacted: 41, added: 300, city: "Seattle", state: "WA", email: "jordan.ellis@example.com", phone: "(206) 555-0142",
                    notes: [("Renewal", "Renewal is due next month. Wants volume pricing for the Tacoma warehouse.", 41),
                            ("", "Met at the Port of Seattle logistics breakfast.", 290)],
                    capabilities: ["Freight", "Warehousing", "Last mile"],
                    publicInfo: "Regional freight and warehousing across the Pacific Northwest.",
                    insight: "Renewal is next month and you haven't talked in six weeks. Check in on the Q3 rollout.", important: true),
            contact("d2", "Priya", "Raman", "Founder & CEO", "Lumen Dental Studio", status: "Proposal", stage: "engaged",
                    lastContacted: 18, added: 60, city: "Portland", state: "OR", email: "priya@example.com", phone: "(503) 555-0187",
                    notes: [("Pricing", "Opened the proposal twice. Asked whether onboarding is included.", 18)],
                    insight: "She's comparing options now. Offer a 15-minute walkthrough."),
            contact("d3", "Marcus", "Bell", "Director of Partnerships", "Northwind Credit Union", status: "Engagement", stage: "follow_up_2",
                    lastContacted: 63, added: 400, city: "Tacoma", state: "WA", email: "mbell@example.com", phone: "(253) 555-0119",
                    notes: [("Workshop", "Co-hosted the small-business workshop. 40 attendees.", 63)]),
            contact("d4", "Elena", "Torres", "Marketing Manager", "Cascade Outdoor Co.", status: "Qualification", stage: "follow_up_1",
                    lastContacted: 9, added: 12, city: "Bend", state: "OR", email: "elena.torres@example.com", phone: "(541) 555-0133",
                    notes: [("Meetup", "Asked for a case study. Send the Harbor Freight story.", 9)]),
            contact("d5", "David", "Kim", "Owner", "Kim & Sons Construction", status: "Closed Won", stage: "won",
                    lastContacted: 120, added: 700, city: "Spokane", state: "WA", email: "david@example.com", phone: "(509) 555-0176",
                    notes: [("Referrals", "Referred two customers last year.", 200)]),
            contact("d6", "Aisha", "Grant", "Head of People", "Brightline Health", status: "Lead Generation", stage: "first_touch",
                    lastContacted: nil, added: 3, city: "Boise", state: "ID", email: "agrant@example.com", phone: "(208) 555-0158"),
            contact("d7", "Sam", "Okafor", "Program Director", "Rainier Youth Alliance", status: "Engagement", stage: "engaged",
                    lastContacted: 5, added: 90, city: "Olympia", state: "WA", email: "sam@example.org", phone: "(360) 555-0104"),
            contact("d8", "Hannah", "Lee", "Procurement Lead", "Evergreen County", status: "Lead Generation", stage: "follow_up_1",
                    lastContacted: 30, added: 45, city: "Everett", state: "WA", email: "hlee@example.gov", phone: "(425) 555-0161"),
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: people),
              let decoded = try? JSONDecoder().decode([ContactDetail].self, from: data)
        else { return [] }
        return decoded
    }()

    static func detail(id: String) -> ContactDetail? {
        details.first { $0.contactId == id }
    }
}
