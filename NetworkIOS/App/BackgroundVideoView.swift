import AVFoundation
import SwiftUI

/// The same looping brand background TODD's marketing site plays behind its
/// home page (`home-background.mp4`, bundled here) — muted and silently
/// looped via `AVPlayerLooper` rather than a stock `VideoPlayer`, which has
/// no built-in seamless-loop API and would show a visible restart flash.
struct BackgroundVideoView: UIViewRepresentable {
    func makeUIView(context: Context) -> PlayerLayerView {
        PlayerLayerView()
    }

    func updateUIView(_ uiView: PlayerLayerView, context: Context) {}

    final class PlayerLayerView: UIView {
        private var queuePlayer: AVQueuePlayer?
        private var looper: AVPlayerLooper?

        override class var layerClass: AnyClass { AVPlayerLayer.self }
        private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

        override init(frame: CGRect) {
            super.init(frame: frame)
            guard let url = Bundle.main.url(forResource: "home-background", withExtension: "mp4") else { return }

            let item = AVPlayerItem(url: url)
            let player = AVQueuePlayer()
            player.isMuted = true
            player.actionAtItemEnd = .none

            looper = AVPlayerLooper(player: player, templateItem: item)
            queuePlayer = player
            playerLayer.player = player
            playerLayer.videoGravity = .resizeAspectFill
            player.play()
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
}
