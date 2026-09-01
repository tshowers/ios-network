import SwiftUI

/// A single full-screen contact card. Deliberately not a list row shrunk down
/// — the person owns the screen, per the product brief ("digital Rolodex that
/// thinks," not a contact list).
struct ContactCardView: View {
    let card: ContactCard
    /// One-line relationship-strategy suggestion from `/contact-insight`
    /// (`getContactInsight` server-side) — e.g. "Good time to reconnect,
    /// their last conversation involved expansion plans." Loaded lazily by
    /// the parent view model; nil until it arrives (if it arrives at all).
    var insight: String?
    /// True when `card.contactId` matches the signed-in user's own uid — TODD
    /// creates a person's own contact record using their uid as the document
    /// id (see `findTenantContactById(tenantId, user.uid)` in the web app's
    /// `getTenantLoggedInContactInfo`), so this is a reliable check, not a
    /// heuristic. Self gets a materially different layout: no relationship
    /// badge, no "last contacted", no insight (none of that makes sense about
    /// yourself) — instead a proper info list of what's actually on file.
    var isSelf: Bool = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 12)

            logoOrMonogram

            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    Text(card.displayName)
                        .font(.system(size: 30, weight: .bold))
                        .multilineTextAlignment(.center)

                    if isSelf {
                        Text("(You)")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                if !card.profession.isEmpty {
                    Text(card.profession)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                if !card.company.name.isEmpty {
                    Text(card.company.name)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }

                if !isSelf, !card.locationLabel.isEmpty {
                    Text(card.locationLabel)
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 24)

            if isSelf {
                selfInfoList
            } else {
                VStack(spacing: 8) {
                    if !card.relationship.isEmpty {
                        Label(card.relationship, systemImage: "person.crop.circle.badge")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.thinMaterial, in: Capsule())
                    }

                    if let lastContactedLabel {
                        Text(lastContactedLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let insight, !insight.isEmpty {
                    Text(insight)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .italic()
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }

            Spacer(minLength: 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.background)
                .shadow(color: .black.opacity(0.12), radius: 24, y: 12)
        )
    }

    private var selfInfoList: some View {
        VStack(spacing: 0) {
            if !card.email.isEmpty {
                infoRow(icon: "envelope.fill", text: card.email, url: URL(string: "mailto:\(card.email)"))
            }
            if !card.phone.isEmpty {
                infoRow(icon: "phone.fill", text: card.phone, url: URL(string: "tel:\(card.phone.filter { $0.isNumber || $0 == "+" })"))
            }
            if !card.linkedInUrl.isEmpty {
                infoRow(icon: "link", text: card.linkedInUrl, url: URL(string: card.linkedInUrl))
            }
            if !card.locationLabel.isEmpty {
                infoRow(icon: "mappin.and.ellipse", text: card.locationLabel, url: nil)
            }
        }
        .padding(.vertical, 4)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 24)
    }

    private func infoRow(icon: String, text: String, url: URL?) -> some View {
        Group {
            if let url {
                Link(destination: url) {
                    infoRowLabel(icon: icon, text: text)
                }
            } else {
                infoRowLabel(icon: icon, text: text)
            }
        }
    }

    private func infoRowLabel(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundStyle(.secondary)
            Text(text)
                .font(.subheadline)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var logoOrMonogram: some View {
        Group {
            if let logoUrlString = card.company.logoUrl, let url = URL(string: logoUrlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFit()
                    default:
                        monogram
                    }
                }
            } else {
                monogram
            }
        }
        .frame(width: 96, height: 96)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var monogram: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(monogramColor)
            .overlay(
                Text(card.monogram)
                    .font(.title.bold())
                    .foregroundStyle(.white)
            )
    }

    /// Deterministic color from the company/person name, so the same card
    /// always renders the same monogram color across launches.
    private var monogramColor: Color {
        let hash = (card.company.name.isEmpty ? card.displayName : card.company.name)
            .unicodeScalars
            .reduce(0) { ($0 << 5) &- $0 &+ Int($1.value) }
        let hue = Double(abs(hash) % 360) / 360.0
        return Color(hue: hue, saturation: 0.55, brightness: 0.72)
    }

    private var lastContactedLabel: String? {
        guard let lastContacted = card.lastContacted, !lastContacted.isEmpty else { return nil }
        guard let date = ISO8601DateFormatter().date(from: lastContacted) else { return nil }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return "Last contact: \(formatter.localizedString(for: date, relativeTo: Date()))"
    }
}
