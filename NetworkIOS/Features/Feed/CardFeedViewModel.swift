import Foundation

@MainActor
final class CardFeedViewModel: ObservableObject {
    @Published var cards: [ContactCard] = []
    @Published var currentIndex = 0
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var searchQuery = ""
    /// Keyed by contactId. Populated lazily, one card at a time, as each
    /// becomes current — never prefetched for a whole page (see
    /// `NetworkAPIClient.fetchInsight`).
    @Published private(set) var insightsByContactId: [String: String] = [:]
    /// Denominator for the header's "N of Total" counter — the tenant's
    /// whole contact count, not just how many pages have been fetched so
    /// far. Reuses `/network/stats` (built for the Network Status screen)
    /// rather than adding a second endpoint just for this number.
    @Published private(set) var totalContacts: Int?

    let apiClient: NetworkAPIClient
    /// TODD creates a person's own contact record using their uid as the
    /// document id, so comparing this to `ContactCard.contactId` reliably
    /// detects "this card is you" - not a heuristic.
    let currentUserId: String?
    private var nextCursor: String?
    private var activeQuery: String?
    /// Once a search query is active, pagination via `cursor` no longer applies
    /// (see the `/network/cards` note on search mode not being cursor-paginated).
    private var isSearchMode = false
    private var insightRequestsInFlight: Set<String> = []

    init(apiClient: NetworkAPIClient, currentUserId: String?) {
        self.apiClient = apiClient
        self.currentUserId = currentUserId
    }

    func isSelf(_ card: ContactCard) -> Bool {
        guard let currentUserId, !currentUserId.isEmpty else { return false }
        return card.contactId == currentUserId
    }

    func insight(for card: ContactCard) -> String? {
        insightsByContactId[card.contactId]
    }

    /// Fire-and-forget; failures are silent since the insight line is a nice-to-have,
    /// not something worth interrupting the card view for. Never fetched for
    /// your own card - "good time to reconnect with yourself" isn't a thing.
    func loadInsightIfNeeded(for card: ContactCard) {
        guard !isSelf(card) else { return }
        guard insightsByContactId[card.contactId] == nil else { return }

        // Pre-computed elsewhere in TODD - if it's there, show it immediately
        // and skip the live call entirely rather than replacing it with a
        // fresh generation the card doesn't need.
        if !card.storedInsight.isEmpty {
            insightsByContactId[card.contactId] = card.storedInsight
            return
        }

        guard !insightRequestsInFlight.contains(card.contactId) else { return }
        insightRequestsInFlight.insert(card.contactId)

        Task {
            defer { insightRequestsInFlight.remove(card.contactId) }
            if let text = try? await apiClient.fetchInsight(for: card), !text.isEmpty {
                insightsByContactId[card.contactId] = text
            }
        }
    }

    var currentCard: ContactCard? {
        cards.indices.contains(currentIndex) ? cards[currentIndex] : nil
    }

    /// Fire-and-forget, same reasoning as `loadInsightIfNeeded` — a header
    /// counter isn't worth blocking the card feed over if it fails.
    func loadTotalContactsIfNeeded() {
        guard totalContacts == nil else { return }
        Task {
            totalContacts = try? await apiClient.fetchStats().totalContacts
        }
    }

    func loadInitial() async {
        guard cards.isEmpty else { return }
        await reload()
    }

    func reload() async {
        isLoading = true
        errorMessage = ""
        currentIndex = 0
        nextCursor = nil
        do {
            let page = try await apiClient.fetchCards(query: activeQuery)
            cards = page.cards
            nextCursor = page.nextCursor
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func runSearch() async {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        activeQuery = trimmed.isEmpty ? nil : trimmed
        isSearchMode = activeQuery != nil
        await reload()
    }

    func clearSearch() async {
        searchQuery = ""
        activeQuery = nil
        isSearchMode = false
        await reload()
    }

    /// Called as the user pages into the last couple of cards, so the next
    /// page is already loaded by the time they get there.
    func loadMoreIfNeeded() async {
        guard !isSearchMode, !isLoading, let nextCursor else { return }
        guard currentIndex >= cards.count - 3 else { return }

        do {
            let page = try await apiClient.fetchCards(cursor: nextCursor)
            cards.append(contentsOf: page.cards)
            self.nextCursor = page.nextCursor
        } catch {
            // Silent - the user hasn't hit the end of the loaded stack yet,
            // no need to interrupt them with an error for a background prefetch.
        }
    }
}
