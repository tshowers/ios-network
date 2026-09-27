import SwiftUI

/// Sits at the very top of any card whose contact has a company.
struct LetterheadBanner: View {
    let companyName: String
    let logoUrl: String?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            VStack(spacing: 8) {
                if let logoUrl, let url = URL(string: logoUrl) {
                    AsyncImage(url: url) { phase in
                        if case .success(let image) = phase {
                            image.resizable().scaledToFit().frame(height: 34)
                        }
                    }
                }

                Text(companyName.uppercased())
                    .font(.system(size: 14, weight: .bold))
                    .tracking(2.5)
                    // Theme-aware: the old fixed dark navy was near-invisible
                    // on the dark-mode card.
                    .foregroundStyle(NetworkTheme(colorScheme: colorScheme).primaryText.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 24)
            }
            .padding(.top, 46)
        }
        .frame(height: 150)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28, style: .continuous))
    }
}
