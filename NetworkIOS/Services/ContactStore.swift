import Foundation

/// Every contact in the tenant, as list rows, shared by the Contacts tab and
/// anything else that needs to look a contact up. Loads all pages of
/// `/mobile/contacts` and keeps a copy on the device so the list opens
/// instantly and still works without a connection.
///
/// The on-device copy is per signed-in user, written with complete file
/// protection (unreadable while the phone is locked), and deleted on sign-out.
@MainActor
final class ContactStore: ObservableObject {
    @Published private(set) var contacts: [ContactSummary] = []
    @Published private(set) var isLoading = false
    @Published private(set) var hasLoadedOnce = false
    @Published var errorMessage = ""

    let apiClient: NetworkAPIClient
    private let userId: String?

    init(apiClient: NetworkAPIClient, userId: String?) {
        self.apiClient = apiClient
        self.userId = userId
        if RelationshipsDemo.isOn {
            contacts = RelationshipsDemo.details.map(ContactSummary.init(detail:))
            hasLoadedOnce = true
            return
        }
        if let cached = Self.readCache(userId: userId) {
            contacts = cached
            hasLoadedOnce = true
        }
    }

    /// Fetches every page. Keeps showing the cached list until the fresh one
    /// is complete, so a dropped connection mid-way never empties the screen.
    func refresh() async {
        guard !isLoading, !RelationshipsDemo.isOn else { return }
        isLoading = true
        errorMessage = ""
        defer { isLoading = false }

        do {
            var all: [ContactSummary] = []
            var cursor: String?
            repeat {
                let page = try await apiClient.fetchContactPage(cursor: cursor)
                all.append(contentsOf: page.contacts)
                cursor = page.nextCursor
            } while cursor != nil

            contacts = all
            hasLoadedOnce = true
            Self.writeCache(all, userId: userId)
        } catch {
            errorMessage = contacts.isEmpty ?
                (error.localizedDescription) :
                "Showing saved contacts. Couldn't refresh: \(error.localizedDescription)"
        }
    }

    func loadIfNeeded() async {
        if contacts.isEmpty || !hasLoadedOnce { await refresh() }
    }

    func contact(id: String) -> ContactSummary? {
        contacts.first { $0.contactId == id }
    }

    /// Inserts or replaces the row for a contact that was just created,
    /// edited or reloaded in full.
    func upsert(_ detail: ContactDetail) {
        let summary = ContactSummary(detail: detail)
        if let index = contacts.firstIndex(where: { $0.contactId == detail.contactId }) {
            contacts[index] = summary
        } else {
            contacts.insert(summary, at: 0)
        }
        Self.writeCache(contacts, userId: userId)
    }

    func remove(id: String) {
        contacts.removeAll { $0.contactId == id }
        Self.writeCache(contacts, userId: userId)
    }

    func delete(id: String) async throws {
        try await apiClient.deleteContact(id: id)
        remove(id: id)
    }

    /// Contact count per status, for the pipeline and filters.
    var countsByStatus: [String: Int] {
        contacts.reduce(into: [:]) { counts, contact in
            counts[contact.status, default: 0] += 1
        }
    }

    // MARK: - On-device copy

    private static func cacheURL(userId: String?) -> URL? {
        guard let userId, !userId.isEmpty,
              let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        else { return nil }
        let safeId = userId.replacingOccurrences(of: "/", with: "_")
        return base.appending(path: "Relationships", directoryHint: .isDirectory).appending(path: "contacts-\(safeId).json")
    }

    private static func readCache(userId: String?) -> [ContactSummary]? {
        guard let url = cacheURL(userId: userId), let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode([ContactSummary].self, from: data)
    }

    private static func writeCache(_ contacts: [ContactSummary], userId: String?) {
        guard let url = cacheURL(userId: userId), let data = try? JSONEncoder().encode(contacts) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: [.atomic, .completeFileProtection])
    }

    /// Deletes every user's saved contacts. Called on sign-out and account deletion.
    static func clearAllCaches() {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        try? FileManager.default.removeItem(at: base.appending(path: "Relationships", directoryHint: .isDirectory))
    }
}
