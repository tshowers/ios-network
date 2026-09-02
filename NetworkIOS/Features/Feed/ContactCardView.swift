import SwiftUI

/// The complete content of one curled page. This is deliberately one composed
/// white page: the navy belongs to the app, while this single surface owns
/// the contact details and actions.
struct ContactCardView: View {
    let card: ContactCard
    var insight: String?
    var isSelf: Bool = false
    var onMaya: (() -> Void)? = nil
    var onShare: ((ContactCard) -> Void)? = nil

    private let blue = Color(red: 0.05, green: 0.32, blue: 0.72)
    private let ink = Color(red: 0.04, green: 0.10, blue: 0.20)

    var body: some View {
        GeometryReader { geometry in
            let designWidth: CGFloat = 430
            let designHeight: CGFloat = 850
            let availableWidth = min(geometry.size.width - 20, 560)
            let availableHeight = geometry.size.height - 16
            let scale = min(availableWidth / designWidth, availableHeight / designHeight)

            pageComposition
                .frame(width: designWidth, height: designHeight)
                .scaleEffect(min(scale, UIDevice.current.userInterfaceIdiom == .pad ? 1.35 : 1.0))
                // scaleEffect is visual only. Report the scaled dimensions
                // to the parent so the page remains centered and cannot be
                // clipped or pushed sideways.
                .frame(
                    width: designWidth * min(scale, UIDevice.current.userInterfaceIdiom == .pad ? 1.35 : 1.0),
                    height: designHeight * min(scale, UIDevice.current.userInterfaceIdiom == .pad ? 1.35 : 1.0)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .preferredColorScheme(.light)
    }

    /// Fixed design-space composition. It is intentionally not a ScrollView:
    /// the entire contact is the page that UIPageViewController curls.
    private var pageComposition: some View {
        VStack(spacing: 0) {
            LetterheadBanner(companyName: card.company.name, logoUrl: card.company.logoUrl)
                .frame(height: 140)

            identitySection
                .padding(.top, 10)

            if hasCommunication {
                contactInfo
                    .padding(.top, 10)
            }

            if !isSelf {
                statsGrid
                    .padding(.top, 10)

                if let insight, !insight.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    insightCard(insight)
                        .padding(.top, 10)
                }
            }

            // Sparse contacts retain the same outer page while the actions
            // remain anchored at its bottom.
            Spacer(minLength: 12)

            actionRow
                .padding(.bottom, 14)
        }
        .padding(.top, 8)
        .background(Color(red: 0.975, green: 0.985, blue: 1))
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).stroke(Color.white.opacity(0.9), lineWidth: 1))
        .shadow(color: .black.opacity(0.16), radius: 16, y: 8)
    }

    private var hasCommunication: Bool {
        !card.email.isEmpty || !card.phone.isEmpty || website != nil || linkedIn != nil
    }

    private var identity: some View {
        VStack(spacing: 5) {
            Text(card.displayName)
                .font(.system(size: 29, weight: .bold, design: .rounded))
                .foregroundStyle(ink)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            if !card.profession.isEmpty {
                Text(card.profession)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            if !card.company.name.isEmpty {
                Text(card.company.name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.blue)
            }
            if !card.locationLabel.isEmpty {
                Label(card.locationLabel, systemImage: "mappin.and.ellipse")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
        }
    }

    private var identitySection: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                identity.padding(.top, 55)

                if !isSelf && (card.important || !card.relationship.isEmpty) {
                    pills.padding(.top, 16)
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.white.opacity(0.85), lineWidth: 1))
            .padding(.horizontal, 24)

            avatar.offset(y: -48)
        }
    }

    private var pills: some View {
        HStack(spacing: 12) {
            if !card.relationship.isEmpty { pill(card.relationship, color: .green, icon: nil) }
            if card.important { pill("Important", color: .orange, icon: "star.fill") }
        }
    }

    private func pill(_ text: String, color: Color, icon: String?) -> some View {
        HStack(spacing: 7) {
            if let icon { Image(systemName: icon).font(.caption.weight(.bold)) }
            else { Circle().fill(color).frame(width: 7, height: 7) }
            Text(text).font(.caption.weight(.semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(color.opacity(0.13), in: Capsule())
        .lineLimit(1)
        .minimumScaleFactor(0.72)
    }

    private var contactInfo: some View {
        VStack(spacing: 2) {
            if !card.email.isEmpty {
                infoRow(icon: "envelope.fill", text: card.email, count: card.additionalEmailCount, url: URL(string: "mailto:\(card.email)"))
            }
            if !card.phone.isEmpty {
                infoRow(icon: "phone.fill", text: card.phone, count: card.additionalPhoneCount, url: URL(string: "tel:\(card.phone.filter { $0.isNumber || $0 == "+" })"))
            }
            if let website, let url = URL(string: website) {
                infoRow(icon: "globe", text: displayURL(website), url: url)
            }
            if let linkedIn, let url = URL(string: linkedIn) {
                infoRow(icon: "link", text: displayURL(linkedIn), url: url)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.72))
        )
        .padding(.horizontal, 24)
    }

    private func infoRow(icon: String, text: String, count: Int = 0, url: URL?) -> some View {
        Group {
            if let url {
                Link(destination: url) {
                    infoRowLabel(icon: icon, text: text, count: count)
                }
                // Link supplies the interaction, but must not apply a
                // button-like row appearance to contact typography.
                .buttonStyle(.plain)
            }
            else { infoRowLabel(icon: icon, text: text, count: count) }
        }
    }

    private func infoRowLabel(icon: String, text: String, count: Int) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(blue)
                .frame(width: 24)
            Text(text)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .truncationMode(.middle)
            Spacer(minLength: 8)
            if count > 0 {
                Text("+\(count)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(blue)
            }
        }
        .frame(height: 36)
    }

    private var statsGrid: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                stat("calendar", "Last Contact", lastContactedValue)
                stat("person.2", "Relationship", card.relationship.isEmpty ? "—" : card.relationship)
                stat("chart.bar.fill", "Engagement", engagementValue)
            }
            Divider().padding(.horizontal, 12)
            HStack(spacing: 0) {
                stat("tag.fill", "Category", card.category.isEmpty ? "—" : card.category)
                stat("megaphone.fill", "Source", card.source.isEmpty ? "—" : card.source)
                stat("target", "Engagement Score", "\(card.contactValue)")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 17, style: .continuous).stroke(blue.opacity(0.10), lineWidth: 1))
        .padding(.horizontal, 24)
    }

    private func stat(_ icon: String, _ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.caption).foregroundStyle(blue)
                Text(label).font(.caption2).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.75)
            }
            Text(value).font(.caption.weight(.semibold)).foregroundStyle(ink).lineLimit(2).minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 7)
        .padding(.vertical, 8)
    }

    private func insightCard(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Label("TODD Insight", systemImage: "sparkles")
                .font(.subheadline.weight(.bold)).foregroundStyle(.blue)
            Text(text.replacingOccurrences(of: "\\n", with: "\n"))
                .font(.subheadline).foregroundStyle(ink.opacity(0.88))
                .lineLimit(5).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(red: 0.86, green: 0.91, blue: 0.99), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 17, style: .continuous).stroke(Color.blue.opacity(0.16), lineWidth: 1))
        .padding(.horizontal, 24)
    }

    private var actionRow: some View {
        HStack(spacing: 12) {
            if let onMaya {
                Button(action: onMaya) {
                    Label("Maya", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ContactActionButtonStyle(fill: blue, foreground: .white, border: .clear))
            }
            if let onShare {
                Button { onShare(card) } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ContactActionButtonStyle(fill: .white, foreground: ink, border: Color.black.opacity(0.14)))
            }
        }
        .padding(.horizontal, 24)
    }

    @ViewBuilder
    private var avatar: some View {
        Group {
            if let logoURL = card.company.logoUrl, let url = URL(string: logoURL) {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase { image.resizable().scaledToFit().padding(18) }
                    else { monogram }
                }
            } else { monogram }
        }
        .frame(width: 96, height: 96)
        .background(.white, in: Circle())
        .clipShape(Circle())
        .overlay(Circle().stroke(blue.opacity(0.22), lineWidth: 3))
        .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
    }

    private var monogram: some View {
        Circle().fill(Color(red: 0.20, green: 0.47, blue: 0.93))
            .overlay(Text(card.monogram).font(.title.bold()).foregroundStyle(.white))
    }

    private var website: String? {
        card.socialMedia.first { $0.platform.lowercased() == "website" }?.url ?? card.company.url
    }

    private var linkedIn: String? {
        if !card.linkedInUrl.isEmpty { return card.linkedInUrl }
        return card.socialMedia.first { $0.platform.lowercased().contains("linkedin") }?.url
    }

    private func displayURL(_ value: String) -> String {
        value.replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private var engagementValue: String {
        let total = card.engagementsCount + card.interactionsCount
        return total == 0 ? "No activity" : "\(total) activity"
    }

    private var lastContactedValue: String {
        guard let raw = card.lastContacted, let date = ISO8601DateFormatter().date(from: raw) else { return "—" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

private struct ContactActionButtonStyle: ButtonStyle {
    let fill: Color
    let foreground: Color
    let border: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(foreground)
            .frame(minHeight: 52)
            .background(fill, in: Capsule())
            .overlay(Capsule().stroke(border, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.78 : 1)
    }
}
