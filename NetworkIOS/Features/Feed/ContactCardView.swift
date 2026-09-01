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
    /// heuristic. Self skips the relationship pill, stats grid, and insight
    /// — none of "last contacted 85 days ago" or "good time to reconnect"
    /// makes sense about yourself — but keeps the info list, since seeing
    /// your own info on file is exactly the point.
    var isSelf: Bool = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 12)

            avatar

            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    Text(card.displayName)
                        .font(.system(size: 28, weight: .bold))
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
                        .foregroundStyle(.blue)
                }

                if !card.locationLabel.isEmpty {
                    Label(card.locationLabel, systemImage: "mappin.and.ellipse")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 24)

            if !isSelf, !card.relationship.isEmpty || card.important {
                pillsRow
            }

            infoList

            if !isSelf {
                statsGrid

                if let insight, !insight.isEmpty {
                    insightCard(insight)
                }
            }

            Spacer(minLength: 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            // `.background` and the page's `.systemGroupedBackground` are
            // nearly the same shade of near-black in dark mode - there was
            // no visible card at all, just flat black. secondary/systemGrouped
            // is the pair iOS actually designs for this "card floating on a
            // grouped page" contrast, in both light and dark automatically.
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.12), radius: 24, y: 12)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(monogramColor.opacity(0.25), lineWidth: 1)
        )
        .overlay(alignment: .topTrailing) {
            if card.important {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                    .padding(10)
                    .background(.thinMaterial, in: Circle())
                    .padding(16)
            }
        }
    }

    // MARK: - Pills

    private var pillsRow: some View {
        HStack(spacing: 10) {
            if !card.relationship.isEmpty {
                pill(text: card.relationship, tint: .green, dot: true)
            }
            if card.important {
                pill(text: "Important", tint: .yellow, icon: "star.fill")
            }
        }
    }

    private func pill(text: String, tint: Color, dot: Bool = false, icon: String? = nil) -> some View {
        HStack(spacing: 6) {
            if dot {
                Circle().fill(tint).frame(width: 7, height: 7)
            } else if let icon {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(tint)
            }
            Text(text)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.thinMaterial, in: Capsule())
    }

    // MARK: - Info list (always shown, placeholders when empty — same
    // treatment TODD's own contact-read gives Website/LinkedIn.)

    private var infoList: some View {
        VStack(spacing: 0) {
            infoRow(
                icon: "envelope.fill",
                text: card.email,
                placeholder: "No email",
                additionalCount: card.additionalEmailCount,
                url: card.email.isEmpty ? nil : URL(string: "mailto:\(card.email)")
            )
            infoRow(
                icon: "phone.fill",
                text: card.phone,
                placeholder: "No phone",
                additionalCount: card.additionalPhoneCount,
                url: card.phone.isEmpty ? nil : URL(string: "tel:\(card.phone.filter { $0.isNumber || $0 == "+" })")
            )
            infoRow(
                icon: "globe",
                text: card.company.url ?? "",
                placeholder: "No website",
                url: card.company.url.flatMap { URL(string: $0) }
            )
            infoRow(
                icon: "link",
                text: card.linkedInUrl,
                placeholder: "No LinkedIn",
                url: card.linkedInUrl.isEmpty ? nil : URL(string: card.linkedInUrl)
            )
        }
        .padding(.vertical, 4)
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 24)
    }

    private func infoRow(icon: String, text: String, placeholder: String, additionalCount: Int = 0, url: URL?) -> some View {
        let isEmpty = text.isEmpty

        return Group {
            if let url {
                Link(destination: url) { infoRowLabel(icon: icon, text: text, isEmpty: isEmpty, placeholder: placeholder, additionalCount: additionalCount) }
            } else {
                infoRowLabel(icon: icon, text: text, isEmpty: isEmpty, placeholder: placeholder, additionalCount: additionalCount)
            }
        }
    }

    private func infoRowLabel(icon: String, text: String, isEmpty: Bool, placeholder: String, additionalCount: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundStyle(.secondary)
            Text(isEmpty ? placeholder : text)
                .font(.subheadline)
                .foregroundStyle(isEmpty ? .tertiary : .primary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            if additionalCount > 0 {
                Text("+\(additionalCount)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.blue)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Stats grid (Engagement / Engagement Score deliberately left
    // out — no real scoring logic exists yet; a placeholder number isn't
    // worth shipping. Revisit once that's designed properly.)

    private var statsGrid: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                statItem(icon: "calendar", label: "Last Contact", value: lastContactedValue)
                statItem(icon: "person.2", label: "Relationship", value: card.relationship.isEmpty ? "—" : card.relationship)
            }
            HStack(spacing: 0) {
                statItem(icon: "tag", label: "Category", value: card.category.isEmpty ? "—" : card.category)
                statItem(icon: "megaphone", label: "Source", value: card.source.isEmpty ? "—" : card.source)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 24)
    }

    private func statItem(icon: String, label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var lastContactedValue: String {
        guard let lastContacted = card.lastContacted, !lastContacted.isEmpty,
              let date = ISO8601DateFormatter().date(from: lastContacted) else {
            return "—"
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    // MARK: - Insight

    private func insightCard(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("TODD Insight", systemImage: "sparkles")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.blue)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 24)
    }

    // MARK: - Avatar

    @ViewBuilder
    private var avatar: some View {
        Group {
            if let logoUrlString = card.company.logoUrl, let url = URL(string: logoUrlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        monogram
                    }
                }
            } else {
                monogram
            }
        }
        .frame(width: 92, height: 92)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(monogramColor.opacity(0.6), lineWidth: 3))
    }

    private var monogram: some View {
        Circle()
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
}
