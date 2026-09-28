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
    /// Raw totals behind the steps (NetworkAwards checks these). Optional
    /// so an older backend without them still decodes.
    let counts: Counts?

    struct Counts: Decodable {
        let contacts: Int
        let staged: Int
        let reachedOut: Int
    }
}

struct GettingStartedEnvelope: Decodable {
    let data: GettingStarted
}
