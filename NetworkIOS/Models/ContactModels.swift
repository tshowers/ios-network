import Foundation

// Models for `/mobile/contacts` (todd-backend networkMobileContacts.service.js).
// Decoding is lenient on purpose: older TODD contacts are missing most
// fields, and one odd document shouldn't fail a whole page.

/// One row in the Contacts list (`toSummaryDto`).
struct ContactSummary: Codable, Identifiable, Hashable {
    var contactId: String
    var firstName: String
    var lastName: String
    var displayName: String
    var profession: String
    var companyName: String
    var logoUrl: String?
    var status: String
    var emailStage: String
    var important: Bool
    var email: String
    var phone: String
    var city: String
    var state: String
    var lastContacted: String?
    var lastUpdated: String?
    var dateAdded: String?
    var isSelf: Bool

    var id: String { contactId }

    var initials: String { ContactFormatting.initials(displayName) }

    var subtitle: String {
        [profession, companyName].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    var lastContactedDate: Date? { ContactFormatting.date(lastContacted) }
    var dateAddedDate: Date? { ContactFormatting.date(dateAdded) }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        contactId = try c.decode(String.self, forKey: .contactId)
        firstName = c.string(.firstName)
        lastName = c.string(.lastName)
        displayName = c.string(.displayName)
        profession = c.string(.profession)
        companyName = c.string(.companyName)
        logoUrl = try? c.decodeIfPresent(String.self, forKey: .logoUrl)
        status = c.string(.status)
        emailStage = c.string(.emailStage)
        important = (try? c.decodeIfPresent(Bool.self, forKey: .important)) ?? false
        email = c.string(.email)
        phone = c.string(.phone)
        city = c.string(.city)
        state = c.string(.state)
        lastContacted = try? c.decodeIfPresent(String.self, forKey: .lastContacted)
        lastUpdated = try? c.decodeIfPresent(String.self, forKey: .lastUpdated)
        dateAdded = try? c.decodeIfPresent(String.self, forKey: .dateAdded)
        isSelf = (try? c.decodeIfPresent(Bool.self, forKey: .isSelf)) ?? false
    }

    /// The list row for a contact just loaded, created or edited in full.
    init(detail: ContactDetail) {
        contactId = detail.contactId
        firstName = detail.firstName
        lastName = detail.lastName
        displayName = detail.displayName
        profession = detail.profession
        companyName = detail.company.name
        logoUrl = detail.company.logoUrl
        status = detail.status
        emailStage = detail.emailStage
        important = detail.important
        email = detail.emailAddresses.first?.emailAddress ?? ""
        phone = detail.phoneNumbers.first?.phoneNumber ?? ""
        city = detail.addresses.first?.city ?? ""
        state = detail.addresses.first?.state ?? ""
        lastContacted = detail.lastContacted
        lastUpdated = detail.lastUpdated
        dateAdded = detail.dateAdded
        isSelf = detail.isSelf
    }
}

struct ContactEmail: Codable, Hashable {
    var emailAddress: String
    var emailAddressType: String
}

struct ContactPhone: Codable, Hashable {
    var phoneNumber: String
    var phoneNumberType: String
}

struct ContactAddress: Codable, Hashable {
    var addressType: String = ""
    var streetAddress: String = ""
    var city: String = ""
    var state: String = ""
    var zip: String = ""
    var county: String = ""
    var country: String = ""

    var isEmpty: Bool { streetAddress.isEmpty && city.isEmpty && state.isEmpty && zip.isEmpty }

    var cityLine: String {
        let cityState = [city, state].filter { !$0.isEmpty }.joined(separator: ", ")
        return [cityState, zip].filter { !$0.isEmpty }.joined(separator: " ")
    }

    var singleLine: String {
        [streetAddress, cityLine, country].filter { !$0.isEmpty }.joined(separator: ", ")
    }
}

struct ContactCompany: Codable, Hashable {
    var name: String = ""
    var url: String?
    var logoUrl: String?
    var publicInfo: String = ""
    var dba: String = ""
    var numberOfEmployees: String = ""
    var sicCode: String = ""
    var capabilities: [String] = []
    var addresses: [ContactAddress] = []

    var hasDetails: Bool {
        !publicInfo.isEmpty || !dba.isEmpty || !numberOfEmployees.isEmpty || !sicCode.isEmpty ||
            !capabilities.isEmpty || addresses.contains { !$0.isEmpty }
    }
}

struct ContactNote: Codable, Hashable, Identifiable {
    var noteId: String
    var subject: String
    var body: String
    var lastUpdated: String?
    var id: String { noteId }
}

struct ContactStatusChange: Codable, Hashable {
    var status: String
    var date: String?
}

struct ContactInteraction: Codable, Hashable {
    var type: String
    var date: String?
    var duration: Int
    var notes: String
}

struct ContactSocial: Codable, Hashable {
    var platform: String
    var url: String
    var username: String?
}

/// A full contact (`toDetailDto`).
struct ContactDetail: Codable, Identifiable, Hashable {
    var contactId: String
    var firstName: String
    var middleName: String
    var lastName: String
    var nickname: String
    var prefix: String
    var displayName: String
    var profession: String
    var category: String
    var profileTypes: [String]
    var company: ContactCompany
    var status: String
    var emailStage: String
    var important: Bool
    var addresses: [ContactAddress]
    var emailAddresses: [ContactEmail]
    var phoneNumbers: [ContactPhone]
    var socialMedia: [ContactSocial]
    var linkedInUrl: String
    var notes: [ContactNote]
    var statusHistory: [ContactStatusChange]
    var birthday: String
    var anniversary: String
    var timezone: String
    var sector: String
    var acquisitionSource: String
    var storedInsight: String
    var interactionsCount: Int
    var recentInteractions: [ContactInteraction]
    var lastContacted: String?
    var lastUpdated: String?
    var dateAdded: String?
    var isSelf: Bool

    var id: String { contactId }
    var initials: String { ContactFormatting.initials(displayName) }
    var stage: EmailStage? { EmailStage(rawValue: emailStage) }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        contactId = try c.decode(String.self, forKey: .contactId)
        firstName = c.string(.firstName)
        middleName = c.string(.middleName)
        lastName = c.string(.lastName)
        nickname = c.string(.nickname)
        prefix = c.string(.prefix)
        displayName = c.string(.displayName)
        profession = c.string(.profession)
        category = c.string(.category)
        profileTypes = (try? c.decodeIfPresent([String].self, forKey: .profileTypes)) ?? []
        company = (try? c.decodeIfPresent(ContactCompany.self, forKey: .company)) ?? ContactCompany()
        status = c.string(.status)
        emailStage = c.string(.emailStage)
        important = (try? c.decodeIfPresent(Bool.self, forKey: .important)) ?? false
        addresses = (try? c.decodeIfPresent([ContactAddress].self, forKey: .addresses)) ?? []
        emailAddresses = (try? c.decodeIfPresent([ContactEmail].self, forKey: .emailAddresses)) ?? []
        phoneNumbers = (try? c.decodeIfPresent([ContactPhone].self, forKey: .phoneNumbers)) ?? []
        socialMedia = (try? c.decodeIfPresent([ContactSocial].self, forKey: .socialMedia)) ?? []
        linkedInUrl = c.string(.linkedInUrl)
        notes = (try? c.decodeIfPresent([ContactNote].self, forKey: .notes)) ?? []
        statusHistory = (try? c.decodeIfPresent([ContactStatusChange].self, forKey: .statusHistory)) ?? []
        birthday = c.string(.birthday)
        anniversary = c.string(.anniversary)
        timezone = c.string(.timezone)
        sector = c.string(.sector)
        acquisitionSource = c.string(.acquisitionSource)
        storedInsight = c.string(.storedInsight)
        interactionsCount = (try? c.decodeIfPresent(Int.self, forKey: .interactionsCount)) ?? 0
        recentInteractions = (try? c.decodeIfPresent([ContactInteraction].self, forKey: .recentInteractions)) ?? []
        lastContacted = try? c.decodeIfPresent(String.self, forKey: .lastContacted)
        lastUpdated = try? c.decodeIfPresent(String.self, forKey: .lastUpdated)
        dateAdded = try? c.decodeIfPresent(String.self, forKey: .dateAdded)
        isSelf = (try? c.decodeIfPresent(Bool.self, forKey: .isSelf)) ?? false
    }
}

/// The 8-step communication stage (web `EmailStages`), driven by Outreach.
enum EmailStage: String, CaseIterable, Identifiable {
    case firstTouch = "first_touch"
    case followUp1 = "follow_up_1"
    case followUp2 = "follow_up_2"
    case engaged
    case meetingPush = "meeting_push"
    case breakup
    case won
    case lost

    var id: String { rawValue }

    var number: Int { (Self.allCases.firstIndex(of: self) ?? 0) + 1 }

    var label: String {
        switch self {
        case .firstTouch: return "First Touch"
        case .followUp1: return "Follow Up 1"
        case .followUp2: return "Follow Up 2"
        case .engaged: return "Engaged"
        case .meetingPush: return "Meeting Push"
        case .breakup: return "Breakup"
        case .won: return "Won"
        case .lost: return "Lost"
        }
    }

    var isOutcome: Bool { self == .won || self == .lost }

    /// The stage after this one; none once the conversation has an outcome.
    var next: EmailStage? {
        guard !isOutcome, self != .breakup else { return nil }
        return Self.allCases[number]
    }
}

/// Pipeline stages, in order (web status-flow's `pipelineStages`).
enum PipelineStage {
    static let all = [
        "Lead Generation", "Qualification", "Engagement", "Proposal",
        "Negotiation", "Closing", "Post-Sale", "Closed Won",
    ]
}

/// Body for POST/PUT `/mobile/contacts`. Every field is sent, so the server
/// stores exactly what the editor shows.
struct ContactInput: Encodable {
    var firstName = ""
    var middleName = ""
    var lastName = ""
    var profession = ""
    var linkedInUrl = ""
    var important = false
    var status = ""
    var company = CompanyInput()
    var emailAddresses: [ContactEmail] = []
    var phoneNumbers: [ContactPhone] = []
    var addresses: [ContactAddress] = []
    /// First note, create only (the server ignores it on update).
    var note: String?

    struct CompanyInput: Encodable {
        var name = ""
        var url = ""
        var publicInfo = ""
        var capabilities: [String] = []
    }

    init() {}

    init(detail: ContactDetail) {
        firstName = detail.firstName
        middleName = detail.middleName
        lastName = detail.lastName
        profession = detail.profession
        linkedInUrl = detail.linkedInUrl
        important = detail.important
        status = detail.status
        company = CompanyInput(
            name: detail.company.name,
            url: detail.company.url ?? "",
            publicInfo: detail.company.publicInfo,
            capabilities: detail.company.capabilities
        )
        emailAddresses = detail.emailAddresses
        phoneNumbers = detail.phoneNumbers
        addresses = detail.addresses
    }

    var displayName: String {
        let name = [firstName, lastName].map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.joined(separator: " ")
        return name.isEmpty ? company.name.trimmingCharacters(in: .whitespaces) : name
    }

    var hasIdentity: Bool {
        !firstName.trimmingCharacters(in: .whitespaces).isEmpty || !company.name.trimmingCharacters(in: .whitespaces).isEmpty
    }
}

struct ContactPage: Decodable {
    let contacts: [ContactSummary]
    let nextCursor: String?
}

/// `{success, data}` envelope used by every `/mobile/contacts` route.
struct DataEnvelope<T: Decodable>: Decodable {
    let data: T
}

enum ContactFormatting {
    static func initials(_ name: String) -> String {
        let letters = name.split(separator: " ").prefix(2).compactMap { $0.first.map(String.init) }.joined()
        return letters.isEmpty ? "?" : letters.uppercased()
    }

    private static let isoFull: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    private static let isoPlain = ISO8601DateFormatter()
    private static let dayOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func date(_ string: String?) -> Date? {
        guard let string, !string.isEmpty else { return nil }
        return isoFull.date(from: string) ?? isoPlain.date(from: string) ?? dayOnly.date(from: String(string.prefix(10)))
    }

    /// "Today", "Yesterday", "3 days ago", or a short date.
    static func relative(_ string: String?) -> String? {
        guard let date = date(string) else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
        if abs(date.timeIntervalSinceNow) < 60 * 60 * 24 * 30 {
            return formatter.localizedString(for: date, relativeTo: Date())
        }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}

extension KeyedDecodingContainer {
    /// A string field, or "" when it's missing, null or not a string.
    func string(_ key: Key) -> String {
        ((try? decodeIfPresent(String.self, forKey: key)) ?? nil) ?? ""
    }
}
