import SwiftUI

/// The main player screen.
///
/// Shows artwork, track metadata, a decorative waveform, transport controls and
/// a chip that opens the preset selector. Audio is wired up in `prepare()` on
/// appear. Phase 1 keeps playback wiring minimal — the focus is the layout and
/// the preset surface.
struct NowPlayingView: View {
    @State var viewModel: NowPlayingViewModel
    @Environment(PresetStore.self) private var presetStore
    @State private var showPresetSelector = false
    @State private var showLibrary = false

    var body: some View {
        ZStack {
            backgroundGradient

            VStack(spacing: DesignTokens.Spacing.l) {
                header
                artwork
                trackInfo
                WaveformView(isAnimating: viewModel.isPlaying)
                    .frame(height: 96)
                    .padding(.horizontal, DesignTokens.Spacing.m)
                transportControls
                Spacer(minLength: 0)
                presetChip
            }
            .padding(DesignTokens.Spacing.l)
        }
        .preferredColorScheme(.dark)
        .onAppear { viewModel.prepare() }
        .sheet(isPresented: $showPresetSelector) {
            PresetSelectorView(
                viewModel: PresetSelectorViewModel(store: presetStore) { preset in
                    viewModel.apply(preset)
                }
            )
        }
        .sheet(isPresented: $showLibrary) {
            LibraryView(viewModel: LibraryViewModel()) { track in
                viewModel.load(track)
            }
        }
    }

    // MARK: - Sections

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                DesignTokens.Palette.backgroundPrimary,
                DesignTokens.Palette.accent.opacity(0.18),
                DesignTokens.Palette.backgroundPrimary
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var header: some View {
        HStack {
            Text("SoundStage")
                .font(DesignTokens.Typography.title)
                .foregroundStyle(DesignTokens.Palette.textPrimary)
            Spacer()
            Button {
                showLibrary = true
            } label: {
                Image(systemName: "music.note.list")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(DesignTokens.Palette.accent)
            }
            .accessibilityLabel("Browse library")
        }
    }

    private var artwork: some View {
        RoundedRectangle(cornerRadius: DesignTokens.Radius.card, style: .continuous)
            .fill(DesignTokens.Palette.cardSurface)
            .overlay(
                Image(systemName: "music.note")
                    .font(.system(size: 64, weight: .light))
                    .foregroundStyle(DesignTokens.Palette.textSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.card, style: .continuous)
                    .stroke(DesignTokens.Palette.cardStroke, lineWidth: 1)
            )
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: 320)
    }

    private var trackInfo: some View {
        VStack(spacing: DesignTokens.Spacing.xs) {
            Text(viewModel.currentTrack.title)
                .font(DesignTokens.Typography.headline)
                .foregroundStyle(DesignTokens.Palette.textPrimary)
                .lineLimit(1)
            Text(viewModel.currentTrack.artist)
                .font(DesignTokens.Typography.body)
                .foregroundStyle(DesignTokens.Palette.textSecondary)
                .lineLimit(1)
        }
    }

    private var transportControls: some View {
        HStack(spacing: DesignTokens.Spacing.xl) {
            transportButton(systemName: "backward.fill", size: 28) {}
            Button(action: viewModel.togglePlayback) {
                Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(DesignTokens.Palette.accent)
            }
            .accessibilityLabel(viewModel.isPlaying ? "Pause" : "Play")
            transportButton(systemName: "forward.fill", size: 28) {}
        }
    }

    private func transportButton(systemName: String, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size))
                .foregroundStyle(DesignTokens.Palette.textPrimary)
        }
    }

    private var presetChip: some View {
        Button {
            showPresetSelector = true
        } label: {
            HStack(spacing: DesignTokens.Spacing.s) {
                Image(systemName: "slider.horizontal.3")
                VStack(alignment: .leading, spacing: 0) {
                    Text("Preset")
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Palette.textSecondary)
                    Text(viewModel.activePreset.label)
                        .font(DesignTokens.Typography.headline)
                        .foregroundStyle(DesignTokens.Palette.textPrimary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(DesignTokens.Palette.textSecondary)
            }
            .padding(DesignTokens.Spacing.m)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.control, style: .continuous)
                    .fill(DesignTokens.Palette.cardSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.control, style: .continuous)
                    .stroke(DesignTokens.Palette.cardStroke, lineWidth: 1)
            )
            .foregroundStyle(DesignTokens.Palette.accent)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    let store = PresetStore()
    NowPlayingView(viewModel: NowPlayingViewModel(presetStore: store))
        .environment(store)
}
