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
            .aspectRatio(contentMode: .fill)
            // Anchored `.top`, not centered: the wave pattern is concentrated
            // near the top of the source image, and the header's white icons
            // need to reliably land on it - a center crop could put the
            // header over a plain white slice instead, depending on the
            // device's aspect ratio, making the icons invisible.
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .clipped()
    }
}
