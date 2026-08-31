import Foundation

/// Request body for `POST /email-drafting/draft`. Mirrors what `draftStructuredEmail`
/// in `todd-backend/functions/emailDrafting.service.js` expects — this is the same
/// endpoint TODD's own web Composer/Catalyst calls for a single-contact draft, not a
/// new drafting path.
struct DraftEmailRequest: Encodable {
    let tenantId: String
    let selectedContact: SelectedContactPayload

    struct SelectedContactPayload: Encodable {
        let id: String
        let firstName: String
        let lastName: String
        let email: String
        let profession: String
        let company: CompanyPayload
        let relationship: String
        let lastContacted: String?

        struct CompanyPayload: Encodable {
            let name: String
        }
    }
}

/// Mirrors `draftStructuredEmail`'s return shape: `{ subject, bodyHtml, summary, ... }`.
/// Only decoding the fields the preview screen actually shows.
struct DraftEmailResponse: Decodable {
    let subject: String
    let bodyHtml: String
    let summary: String?
}

struct DraftEmailEnvelope: Decodable {
    let success: Bool
    let data: DraftEmailResponse
}

/// Request body for `POST /send-email` — same endpoint SayIt's `EmailService` and
/// TODD web use. Sending requires the signed-in user to already have a mailbox
/// connected via TODD web onboarding (senderResolution.service handles that
/// server-side); there is no in-app mailbox-connection flow here.
struct SendEmailRequest: Encodable {
    let to: String
    let subject: String
    let html: String
    let tenantId: String
}

/// Request body for `POST /contact-insight` — mirrors `getContactInsight` in
/// `todd-backend/functions/open-ai.js`, which takes a loosely-shaped contact
/// profile and returns a one-line relationship-strategy suggestion. Same
/// static-key auth as `/email-drafting/draft`.
struct ContactInsightRequest: Encodable {
    let profile: Profile

    struct Profile: Encodable {
        let firstName: String
        let lastName: String
        let profession: String
        let companyName: String
        let relationship: String
        let lastContacted: String?
    }
}

struct ContactInsightResponse: Decodable {
    let response: String
}
