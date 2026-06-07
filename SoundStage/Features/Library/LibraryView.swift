import SwiftUI

/// The local-library browser, presented as a sheet from the player.
///
/// Renders the view model's state machine: requesting access, denied, loading,
/// an empty state, or a searchable track list. Selecting a track hands it back
/// via `onSelect` and dismisses.
struct LibraryView: View {
    @State var viewModel: LibraryViewModel
    /// Hands back the chosen track plus the list it was chosen from, so the
    /// player can build a queue for prev/next.
    let onSelect: (Track, [Track]) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            content
                .background(DesignTokens.Palette.backgroundPrimary.ignoresSafeArea())
                .navigationTitle("Library")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { dismiss() }
                            .foregroundStyle(DesignTokens.Palette.accent)
                    }
                }
        }
        .presentationBackground(DesignTokens.Palette.backgroundPrimary)
        .task { await viewModel.loadIfNeeded() }
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
                message: "There are no songs in your local music library yet."
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
                .disabled(!track.isPlayable)
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

            if track.isPlayable {
                if track.duration > 0 {
                    Text(track.formattedDuration)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Palette.textSecondary)
                        .monospacedDigit()
                }
            } else {
                Image(systemName: "lock.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(DesignTokens.Palette.textSecondary)
                    .accessibilityLabel("Protected, can't be played")
            }
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
        .opacity(track.isPlayable ? 1 : 0.4)
        .contentShape(Rectangle())
    }
}

#Preview {
    LibraryView(viewModel: LibraryViewModel()) { _, _ in }
        .environment(ArtworkLoader())
}
