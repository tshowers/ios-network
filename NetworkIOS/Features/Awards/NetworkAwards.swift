import Foundation
import TODDAwardsKit

/// Network's awards on the shared, account-synced TODDAwardsKit - the same
/// set on iPhone and iPad, each award celebrated once (the server decides
/// what's new). Most are checked against the real counts that
/// `/network/getting-started` returns, so they can't drift from the data.
enum NetworkAwards {
    static let ladder: [Award] = [
        Award(id: "introduction", title: "The Introduction", copy: "Your profile is complete. People know who they're talking to.", symbol: "person.text.rectangle.fill"),
        Award(id: "connector", title: "The Connector", copy: "Your first contact is in. Every network starts with one.", symbol: "person.2.fill"),
        Award(id: "organizer", title: "The Organizer", copy: "You gave a relationship a stage. Now it's going somewhere.", symbol: "tag.fill"),
        Award(id: "first-reach", title: "The Reach Out", copy: "You didn't just collect a contact \u{2014} you talked to them.", symbol: "paperplane.fill"),
        Award(id: "card-swap", title: "The Card Swap", copy: "You shared a card. Old school, still works.", symbol: "rectangle.portrait.on.rectangle.portrait.fill"),
        Award(id: "strategist", title: "The Strategist", copy: "Five relationships staged. You have a plan.", symbol: "square.grid.3x3.fill"),
        Award(id: "all-set", title: "The Regular", copy: "Getting Started, finished. You know your way around.", symbol: "checkmark.seal.fill"),
        Award(id: "follow-through", title: "The Follow-Through", copy: "Ten people heard from you. That's how relationships last.", symbol: "arrow.uturn.forward.circle.fill"),
        Award(id: "rolodex", title: "The Rolodex", copy: "A hundred contacts. That's a real network.", symbol: "rectangle.stack.fill"),
        Award(id: "kingpin", title: "The Kingpin", copy: "Five hundred people. You know everybody.", symbol: "crown.fill", hidden: true),
    ]

    @MainActor
    static func makeService(authService: AuthService) -> AwardsService {
        AwardsService(
            appName: "Network",
            ladder: ladder,
            api: AwardsAPI(
                baseURL: AppConfig.fromBundle().apiBaseURL,
                product: "network",
                idToken: { @MainActor [weak authService] in
                    guard let authService else { throw AuthServiceError.notSignedIn }
                    return try await authService.freshIdToken()
                }
            )
        )
    }
}

/// Network's record points - each checked at the moment it could become true.
extension AwardsService {
    /// Checked whenever the feed loads or the Getting Started page closes.
    func recordProgress(_ progress: GettingStarted) {
        if progress.steps.first(where: { $0.id == "profile" })?.done == true { unlock("introduction") }
        if progress.allDone { unlock("all-set") }
        guard let counts = progress.counts else { return }
        if counts.contacts >= 1 { unlock("connector") }
        if counts.contacts >= 100 { unlock("rolodex") }
        if counts.contacts >= 500 { unlock("kingpin") }
        if counts.staged >= 1 { unlock("organizer") }
        if counts.staged >= 5 { unlock("strategist") }
        if counts.reachedOut >= 1 { unlock("first-reach") }
        if counts.reachedOut >= 10 { unlock("follow-through") }
    }

    func recordCardShared() {
        unlock("card-swap")
    }
}
