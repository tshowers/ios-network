import SwiftUI
import UIKit

/// Design tokens from the Network family handoff
/// (`corporate/design_handoff_network_contact_detail/README.md`, "Design
/// Tokens"), as adaptive colors: each token resolves to its light or dark
/// value with the system appearance, so views never branch on colorScheme.
enum RT {
    static let bg = Color(light: 0xffffff, dark: 0x0c0e13)
    static let surface = Color(light: 0xf2f3f6, dark: 0x171a22)
    static let surface2 = Color(light: 0xe4e7ed, dark: 0x242936)
    static let text = Color(light: 0x0f1115, dark: 0xf2f4f8)
    static let muted = Color(light: 0x5a6170, dark: 0x9aa2b2)
    static let blue = Color(light: 0x2f6bff, dark: 0x3d7bff)

    /// Background / foreground pair for pills, icon tiles and avatars.
    struct Tint {
        let bg: Color
        let fg: Color
    }

    static let tintBlue = Tint(bg: Color(light: 0xe3ecff, dark: 0x15254a), fg: Color(light: 0x1d4fd6, dark: 0xa3c1ff))
    static let tintCyan = Tint(bg: Color(light: 0xdaf6fc, dark: 0x0c2d35), fg: Color(light: 0x08657d, dark: 0x74e4f8))
    static let tintViolet = Tint(bg: Color(light: 0xefe5ff, dark: 0x2a1847), fg: Color(light: 0x6427c9, dark: 0xcdaaff))
    static let tintGreen = Tint(bg: Color(light: 0xe0f6e6, dark: 0x0e2c19), fg: Color(light: 0x17703a, dark: 0x80e2a4))
    static let tintRed = Tint(bg: Color(light: 0xfde6e4, dark: 0x3a1512), fg: Color(light: 0xa8261d, dark: 0xff9d95))
    static let tintGrey = Tint(bg: Color(light: 0xe4e7ed, dark: 0x242936), fg: Color(light: 0x3d4350, dark: 0xc3c9d6))
    // Yellow and pink appear in the facelift handoff (lanes, Tip card,
    // High Intent) without hex values; these follow the same ramp.
    static let tintYellow = Tint(bg: Color(light: 0xfff4d6, dark: 0x3a2e0c), fg: Color(light: 0x8a5a00, dark: 0xffd770))
    static let tintPink = Tint(bg: Color(light: 0xfde4f1, dark: 0x3a1229), fg: Color(light: 0xa11d63, dark: 0xff9fd0))

    /// Status pill tints from the Contacts table spec (15c) and the pipeline
    /// lane tints (15f). Custom statuses fall back to grey.
    static func statusTint(_ status: String) -> Tint {
        switch status.lowercased() {
        case "lead generation": return tintCyan
        case "qualification": return tintBlue
        case "engagement": return tintViolet
        case "proposal": return tintYellow
        case "negotiation": return tintPink
        case "closing", "post-sale", "closed won", "deliverable": return tintGreen
        default: return tintGrey
        }
    }

    // Radii (handoff: 24 cards on phone, 20/16 inner panels, 12 icon tiles).
    static let cardRadius: CGFloat = 24
    static let panelRadius: CGFloat = 16
    static let tileRadius: CGFloat = 12
}

extension Color {
    /// A color that resolves to `light` or `dark` (0xRRGGBB) with the trait
    /// collection's appearance.
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(rgb: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

private extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xff) / 255,
            green: CGFloat((rgb >> 8) & 0xff) / 255,
            blue: CGFloat(rgb & 0xff) / 255,
            alpha: 1
        )
    }
}

// MARK: - Shared building blocks

/// `--surface` section card (handoff: radius 24, padding 16 on phone).
struct RTCard<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RT.surface, in: RoundedRectangle(cornerRadius: RT.cardRadius, style: .continuous))
    }
}

/// Uppercase 12/700 eyebrow label.
struct RTEyebrow: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 12, weight: .bold))
            .tracking(0.7)
            .foregroundStyle(RT.muted)
    }
}

/// Tinted capsule pill (handoff: 12–14px/700).
struct RTPill: View {
    let text: String
    let tint: RT.Tint
    var systemImage: String?

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage { Image(systemName: systemImage).font(.system(size: 11, weight: .bold)) }
            Text(text)
        }
        .font(.system(size: 13, weight: .bold))
        .lineLimit(1)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .foregroundStyle(tint.fg)
        .background(tint.bg, in: Capsule())
    }
}

/// Circular initials avatar in a tint, or the company logo when there is one.
struct RTAvatar: View {
    let initials: String
    var logoURL: URL?
    var size: CGFloat = 40
    var tint: RT.Tint = RT.tintBlue

    var body: some View {
        ZStack {
            Circle().fill(tint.bg)
            Text(initials)
                .font(.system(size: size * 0.36, weight: .bold))
                .foregroundStyle(tint.fg)
            if let logoURL {
                AsyncImage(url: logoURL) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFit().padding(size * 0.14)
                            .frame(width: size, height: size)
                            .background(Color.white, in: Circle())
                    }
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }
}
