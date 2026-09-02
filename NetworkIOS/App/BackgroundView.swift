import SwiftUI

/// TODD's brand background - a static image rather than the looping
/// `home-background.mp4` the web app uses (a live video decoder behind
/// every screen was too much for Xcode/Simulator, which crashed while
/// bundling/running it). iPad and iPhone get separate assets since the
/// source images are framed for each aspect ratio, not one stretched image.
struct BackgroundView: View {
    var body: some View {
        // The contact page is transparent. Keep one deliberate app-level
        // background behind it instead of using the portrait artwork as a
        // full-screen image; that asset contains a dark photographic mark at
        // its top which does not belong in the card design.
        LinearGradient(
            colors: [
                Color(red: 0.02, green: 0.12, blue: 0.25),
                Color(red: 0.04, green: 0.24, blue: 0.48)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
