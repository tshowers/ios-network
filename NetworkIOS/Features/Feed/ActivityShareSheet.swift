import SwiftUI
import UIKit

/// Thin wrapper so `UIActivityViewController` (AirDrop/Messages/Mail/Save
/// Contact) can be presented from SwiftUI's `.sheet`.
struct ActivityShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
