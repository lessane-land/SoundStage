import SwiftUI

/// Music search/browse sheet (Deezer). DRM-free 30s previews that play through
/// the 16D engine. Shows popular tracks before you type, live results after.
struct MusicBrowserView: View {
    @State var viewModel: MusicBrowserViewModel
    let preset: Preset
    var currentTrackID: String?

    @Environment(\.dismiss) private var dismiss
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            searchField
            content
        }
        .background(DesignTokens.Palette.backgroundPrimary.ignoresSafeArea())
        .presentationBackground(DesignTokens.Palette.backgroundPrimary)
        .preferredColorScheme(.dark)
        .task { await viewModel.loadBrowseIfNeeded() }
    }

    private var header: some View {
        HStack {
            HStack(spacing: 9) {
                Image(systemName: "music.note")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(preset.toColor)
                Text("Music")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(.white.opacity(0.08)))
            }
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    private var searchField: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundStyle(.white.opacity(0.45))
            TextField("Artists, songs, albums", text: $viewModel.query)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
                .tint(preset.toColor)
                .focused($searchFocused)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onChange(of: viewModel.query) { _, _ in viewModel.search() }
            if !viewModel.query.isEmpty {
                Button { viewModel.query = ""; viewModel.search() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.white.opacity(0.08))
        )
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            ProgressView().tint(preset.toColor)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .error(let text):
            message(icon: "wifi.slash", title: "Offline", detail: text)
        case .empty:
            message(icon: "magnifyingglass",
                    title: viewModel.isSearching ? "No results for \u{201C}\(viewModel.query)\u{201D}" : "Nothing here",
                    detail: "Try another artist, song, or album.")
        case .browse, .results:
            list
        }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                Text(viewModel.isSearching ? "Results" : "Popular")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .tracking(0.4)
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)

                ForEach(viewModel.displayed) { track in
                    Button {
                        searchFocused = false
                        viewModel.play(track)
                        dismiss()
                    } label: {
                        SongRow(track: track, preset: preset, isCurrent: track.id == currentTrackID)
                    }
                    .buttonStyle(ScaleButtonStyle(pressedScale: 0.98))
                }
            }
            .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.immediately)
    }

    private func message(icon: String, title: String, detail: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(.white.opacity(0.2))
            Text(title)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
            Text(detail)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.35))
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct SongRow: View {
    let track: Track
    let preset: Preset
    let isCurrent: Bool

    var body: some View {
        HStack(spacing: 12) {
            ArtworkView(track: track, cornerRadius: 9, placeholderIconSize: 16)
                .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(isCurrent ? preset.toColor : .white)
                    .lineLimit(1)
                Text(track.albumTitle.isEmpty ? track.artist : "\(track.artist) · \(track.albumTitle)")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.42))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Image(systemName: isCurrent ? "speaker.wave.2.fill" : "chevron.right")
                .font(.system(size: isCurrent ? 12 : 11, weight: .semibold))
                .foregroundStyle(isCurrent ? preset.toColor : .white.opacity(0.25))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 20)
        .contentShape(Rectangle())
    }
}
