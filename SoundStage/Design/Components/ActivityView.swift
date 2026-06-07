import SwiftUI
import UIKit

/// Wraps `UIActivityViewController` so exported 16D files can be shared (save to
/// Files, AirDrop, Messages, social apps, etc.).
struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
