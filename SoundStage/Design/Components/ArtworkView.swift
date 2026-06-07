import SwiftUI
import UIKit

/// Displays a track's album artwork, falling back to a glass placeholder.
///
/// Pulls the `ArtworkLoader` from the environment and loads asynchronously,
/// re-running whenever the track changes. Decorative, so hidden from
/// accessibility — the track's title/artist carry the information.
struct ArtworkView: View {
    let track: Track
    var cornerRadius: CGFloat = DesignTokens.Radius.control
    var placeholderIconSize: CGFloat = 22

    @Environment(ArtworkLoader.self) private var loader
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let url = track.artworkURL {
                // Apple Music: remote artwork.
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        placeholder
                    }
                }
            } else if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                placeholder
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(DesignTokens.Palette.cardStroke, lineWidth: 1)
        )
        .task(id: track.id) {
            guard track.artworkURL == nil else { return }
            image = await loader.image(for: track, size: CGSize(width: 600, height: 600))
        }
        .accessibilityHidden(true)
    }

    private var placeholder: some View {
        DesignTokens.Palette.cardSurface
            .overlay(
                Image(systemName: "music.note")
                    .font(.system(size: placeholderIconSize, weight: .light))
                    .foregroundStyle(DesignTokens.Palette.textSecondary)
            )
    }
}
