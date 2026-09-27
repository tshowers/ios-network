import Foundation
import TODDProfileKit

/// Answers from `OnboardingWizardView`, collected before sign-in and saved
/// to the user's TODD profile afterwards by
/// `AuthService.submitOnboardingProfileIfNeeded()` (`POST /api/onboarding/profile`,
/// which only fills blank profile fields). Persisted in `UserDefaults` so a
/// quit mid-wizard resumes where it left off, and so a failed save retries
/// on the next launch instead of losing the answers.
struct OnboardingProfileDraft: Codable, Equatable {
    var firstName = ""
    var lastName = ""
    var role = OnboardingProfileDraft.defaultRole
    var companyName = ""
    var helpWith: [String] = []
    var helpNote = ""
    var timezone = TimeZone.current.identifier
    /// Set once the user reaches the sign-in step - a draft that was never
    /// finished (they tapped "Already have an account?") isn't submitted.
    var isReadyToSubmit = false

    /// Roles that live in their contacts - one is always preselected so the
    /// step is a single tap. "Other" (not stored) reveals a free-text field.
    /// Shared with the in-app profile screen via TODDProfileKit.
    static let roleOptions = ProfileChoices.roles
    static let defaultRole = ProfileChoices.defaultRole

    /// True when the role is a custom one typed under "Other".
    var hasCustomRole: Bool { !Self.roleOptions.contains(role) }

    static let helpOptions = [
        "Reconnect with quiet contacts",
        "Follow up faster",
        "Find referrals and introductions",
        "Clean up my contacts",
        "Grow my sales pipeline",
        "Stay on top of key relationships",
    ]

    /// "Help me reconnect with quiet contacts and follow up faster. <note>" -
    /// stored in `jobDescriptionForTODD`, the same field TODD's profile
    /// wizard asks "What should TODD help you do each week?" for.
    var jobDescription: String {
        let goals = helpWith.map { $0.prefix(1).lowercased() + $0.dropFirst() }
        var sentence = ""
        switch goals.count {
        case 0: break
        case 1: sentence = "Help me \(goals[0])."
        default: sentence = "Help me \(goals.dropLast().joined(separator: ", ")) and \(goals.last!)."
        }
        let note = helpNote.trimmingCharacters(in: .whitespacesAndNewlines)
        return [sentence, note].filter { !$0.isEmpty }.joined(separator: " ")
    }

    /// Body for `POST /api/onboarding/profile`. `role` goes to `profession` -
    /// the Contact's `role` field is the admin/reviewer/contractor permission.
    var requestBody: [String: Any] {
        [
            "source": "network-ios",
            "profile": [
                "firstName": firstName,
                "lastName": lastName,
                "profession": role,
                "companyName": companyName,
                "jobDescriptionForTODD": jobDescription,
                "timezone": timezone,
            ],
        ]
    }

    // MARK: - Persistence

    private static let storageKey = "network.onboardingProfileDraft"

    static func load() -> OnboardingProfileDraft {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let draft = try? JSONDecoder().decode(OnboardingProfileDraft.self, from: data) else {
            return OnboardingProfileDraft()
        }
        return draft
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
}
