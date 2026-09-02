import SwiftUI

/// Sits at the very top of any card whose contact has a company, reusing the
/// exact same brand wave art as the app's own background (`BackgroundView`)
/// rather than a hand-drawn gradient — the source image is a tall portrait
/// crop with the wave pattern concentrated near the top, so this shows just
/// that band (anchored `.top`, not stretched) rather than the whole image
/// squeezed into a short banner.
struct LetterheadBanner: View {
    let companyName: String
    let logoUrl: String?

    private var backgroundImageName: String {
        UIDevice.current.userInterfaceIdiom == .pad ? "iPadBackground" : "iPhoneBackground"
    }

    var body: some View {
        ZStack {
            Image(backgroundImageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                // The source artwork has an unwanted dark mark at its very
                // top. Crop above it and use the clean wave band for the
                // company header.
                .offset(y: -150)
                .frame(maxWidth: .infinity, maxHeight: 150, alignment: .top)
                .clipped()

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
                    .foregroundStyle(Color(red: 0.05, green: 0.1, blue: 0.2))
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
