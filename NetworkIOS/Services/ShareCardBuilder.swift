import Foundation
import Contacts

/// Builds a native `CNContact`/vCard from a `ContactCard` for the Share button.
/// Entirely client-side — the card already has everything a vCard needs, no
/// backend round-trip required.
enum ShareCardBuilder {
    static func vCardData(for card: ContactCard) -> Data? {
        let contact = CNMutableContact()
        contact.givenName = card.firstName
        contact.familyName = card.lastName
        contact.organizationName = card.company.name
        contact.jobTitle = card.profession

        if !card.email.isEmpty {
            contact.emailAddresses = [CNLabeledValue(label: CNLabelWork, value: card.email as NSString)]
        }

        if !card.phone.isEmpty {
            contact.phoneNumbers = [CNLabeledValue(label: CNLabelWork, value: CNPhoneNumber(stringValue: card.phone))]
        }

        if let urlString = card.company.url, !urlString.isEmpty {
            contact.urlAddresses = [CNLabeledValue(label: CNLabelWork, value: urlString as NSString)]
        }

        if !card.city.isEmpty || !card.state.isEmpty {
            let address = CNMutablePostalAddress()
            address.city = card.city
            address.state = card.state
            contact.postalAddresses = [CNLabeledValue(label: CNLabelWork, value: address)]
        }

        return try? CNContactVCardSerialization.data(with: [contact])
    }

    /// Writes the vCard to a temporary file so it can be handed to
    /// `UIActivityViewController` with a proper filename (AirDrop/Messages show
    /// the contact's name rather than a generic blob).
    static func temporaryVCardFile(for card: ContactCard) -> URL? {
        guard let data = vCardData(for: card) else { return nil }

        let fileName = "\(card.displayName.isEmpty ? "contact" : card.displayName).vcf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}
