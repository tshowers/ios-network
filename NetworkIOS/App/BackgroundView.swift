import SwiftUI

/// TODD's brand background - a static image rather than the looping
/// `home-background.mp4` the web app uses (a live video decoder behind
/// every screen was too much for Xcode/Simulator, which crashed while
/// bundling/running it). iPad and iPhone get separate assets since the
/// source images are framed for each aspect ratio, not one stretched image.
struct BackgroundView: View {
    var body: some View {
        Image(UIDevice.current.userInterfaceIdiom == .pad ? "iPadBackground" : "iPhoneBackground")
            .resizable()
            .scaledToFill()
    }
}
