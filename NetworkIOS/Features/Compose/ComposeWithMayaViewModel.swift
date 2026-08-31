import Foundation

enum ComposeStage {
    case drafting
    case previewing
    case sending
    case sent
    case failed(String)
}

/// Draft → preview → explicit send, never auto-send. This mirrors TODD's
/// existing draft-only/approval-first policy elsewhere in the product — Maya
/// drafts here exactly the way she does for web Composer/Catalyst
/// (`/email-drafting/draft`), and nothing goes out until the user taps Send.
@MainActor
final class ComposeWithMayaViewModel: ObservableObject {
    @Published var stage: ComposeStage = .drafting
    @Published var subject = ""
    @Published var bodyHTML = ""
    @Published var summary: String?

    let card: ContactCard
    private let apiClient: NetworkAPIClient

    init(card: ContactCard, apiClient: NetworkAPIClient) {
        self.card = card
        self.apiClient = apiClient
    }

    func loadDraft() async {
        stage = .drafting
        do {
            let draft = try await apiClient.draftEmail(for: card)
            subject = draft.subject
            bodyHTML = draft.bodyHtml
            summary = draft.summary
            stage = .previewing
        } catch {
            stage = .failed(error.localizedDescription)
        }
    }

    func send() async {
        guard !card.email.isEmpty else {
            stage = .failed("This contact has no email address on file.")
            return
        }

        stage = .sending
        do {
            try await apiClient.sendEmail(to: card.email, subject: subject, html: bodyHTML)
            stage = .sent
        } catch {
            stage = .failed(error.localizedDescription)
        }
    }
}
