import SwiftUI
import UniformTypeIdentifiers

/// The library browser, presented as a sheet from the player.
///
/// Renders the view model's state machine and a searchable track list, plus an
/// "Import" action to bring in any DRM-free audio file (which the 16D engine
/// can process). Selecting a track hands it back via `onSelect`.
struct LibraryView: View {
    @State var viewModel: LibraryViewModel
    let onSelect: (Track, [Track]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showImporter = false

    var body: some View {
        NavigationStack {
            content
                .background(DesignTokens.Palette.backgroundPrimary.ignoresSafeArea())
                .navigationTitle("Library")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { showImporter = true } label: {
                            Label("Import", systemImage: "plus")
                                .foregroundStyle(DesignTokens.Palette.accent)
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { dismiss() }
                            .foregroundStyle(DesignTokens.Palette.accent)
                    }
                }
        }
        .presentationBackground(DesignTokens.Palette.backgroundPrimary)
        .task { await viewModel.loadIfNeeded() }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.audio], allowsMultipleSelection: false) { result in
            importPicked(result)
        }
    }

    /// Copies the picked DRM-free file into the app and plays it (16D-able).
    private func importPicked(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let source = urls.first else { return }
        let accessed = source.startAccessingSecurityScopedResource()
        defer { if accessed { source.stopAccessingSecurityScopedResource() } }

        let dest = FileManager.default.temporaryDirectory.appendingPathComponent(source.lastPathComponent)
        try? FileManager.default.removeItem(at: dest)
        guard (try? FileManager.default.copyItem(at: source, to: dest)) != nil else { return }

        let track = Track(
            id: "import:\(dest.lastPathComponent)",
            title: source.deletingPathExtension().lastPathComponent,
            artist: "Imported file",
            albumTitle: "",
            duration: 0,
            assetURL: dest,
            artworkID: nil,
            isPlayable: true,
            origin: .local
        )
        onSelect(track, [track])
        dismiss()
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .requestingAccess, .loading:
            loadingState
        case .accessDenied:
            messageState(
                systemImage: "lock.fill",
                title: "No library access",
                message: "Allow access to your music library in Settings to browse and play your tracks."
            )
        case .empty:
            messageState(
                systemImage: "music.note.list",
                title: "No songs found",
                message: "There are no songs in your music library yet."
            )
        case .loaded:
            trackList
        }
    }

    private var trackList: some View {
        List {
            ForEach(viewModel.visibleTracks) { track in
                Button {
                    onSelect(track, viewModel.playableTracks)
                    dismiss()
                } label: {
                    TrackRow(track: track)
                }
                .listRowBackground(Color.clear)
                .listRowSeparatorTint(DesignTokens.Palette.cardStroke)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .searchable(text: $viewModel.searchText, prompt: "Search songs or artists")
        .refreshable { await viewModel.reload() }
    }

    private var loadingState: some View {
        VStack(spacing: DesignTokens.Spacing.m) {
            ProgressView()
                .tint(DesignTokens.Palette.accent)
            Text("Loading your library...")
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(DesignTokens.Palette.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func messageState(systemImage: String, title: String, message: String) -> some View {
        VStack(spacing: DesignTokens.Spacing.m) {
            Image(systemName: systemImage)
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(DesignTokens.Palette.textSecondary)
            Text(title)
                .font(DesignTokens.Typography.headline)
                .foregroundStyle(DesignTokens.Palette.textPrimary)
            Text(message)
                .font(DesignTokens.Typography.body)
                .foregroundStyle(DesignTokens.Palette.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(DesignTokens.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// A single row in the track list.
private struct TrackRow: View {
    let track: Track

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.m) {
            ArtworkView(track: track, placeholderIconSize: 18)
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(DesignTokens.Typography.body)
                    .foregroundStyle(DesignTokens.Palette.textPrimary)
                    .lineLimit(1)
                Text(track.artist)
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Palette.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            if track.origin == .appleMusic {
                // Plays through the system player (no spatial effects).
                Image(systemName: "cloud")
                    .font(.system(size: 12))
                    .foregroundStyle(DesignTokens.Palette.textSecondary)
                    .accessibilityLabel("Apple Music, plays without effects")
            }

            if track.duration > 0 {
                Text(track.formattedDuration)
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Palette.textSecondary)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
        .contentShape(Rectangle())
    }
}

#Preview {
    LibraryView(viewModel: LibraryViewModel()) { _, _ in }
        .environment(ArtworkLoader())
}
