import Foundation

/// Mirrors `GET /network/getting-started` (todd-backend gettingStarted.service.js):
/// the checklist is computed server-side from real data so iOS and web agree.
struct GettingStarted: Decodable {
    struct Step: Decodable, Identifiable {
        let id: String
        let title: String
        let detail: String
        let done: Bool
    }

    let steps: [Step]
    let completedSteps: Int
    let totalSteps: Int
    let allDone: Bool
}

struct GettingStartedEnvelope: Decodable {
    let data: GettingStarted
}
