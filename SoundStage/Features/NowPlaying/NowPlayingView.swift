import SwiftUI

/// The main player. Album art, a preset pill, the gradient waveform scrubber and
/// transport controls — all re-themed to the active preset's gradient. The
/// chevron and pill open the preset selector; the queue icon opens the library.
struct NowPlayingView: View {
    @State var viewModel: NowPlayingViewModel
    @Environment(PresetStore.self) private var presetStore

    @State private var showPresetSelector = false
    @State private var showLibrary = false
    @State private var showSearch = false
    @State private var shuffle = false
    @State private var repeatOn = false

    private var preset: Preset { viewModel.activePreset }

    var body: some View {
        ZStack {
            DesignTokens.Palette.backgroundPrimary.ignoresSafeArea()
            ambientGlow

            VStack(spacing: 0) {
                topBar
                    .padding(.top, 8)

                albumArt
                    .padding(.top, 22)

                presetPill
                    .padding(.top, 20)

                trackInfo
                    .padding(.top, 18)

                Spacer(minLength: 8)

                waveformSection

                transportControls
                    .padding(.top, 16)

                rotationControl
                    .padding(.top, 16)

                EQSpectrumView(preset: preset, isPlaying: viewModel.isPlaying)
                    .frame(height: 72)
                    .opacity(0.92)
                    .padding(.top, 14)
                    .padding(.bottom, 6)
            }
            .padding(.horizontal, 24)
        }
        .preferredColorScheme(.dark)
        .onAppear { viewModel.prepare() }
        .sheet(isPresented: $showPresetSelector) {
            PresetSelectorView(
                viewModel: PresetSelectorViewModel(
                    store: presetStore,
                    onApply: { viewModel.apply($0) },
                    onPreview: { viewModel.previewPreset($0) },
                    onCancelPreview: { viewModel.cancelPreview() }
                )
            )
        }
        .sheet(isPresented: $showLibrary) {
            LibraryView(viewModel: LibraryViewModel()) { track, queue in
                viewModel.play(track, in: queue)
            }
        }
        .sheet(isPresented: $showSearch) {
            MusicBrowserView(
                viewModel: makeBrowserViewModel(),
                preset: preset,
                currentTrackID: viewModel.currentTrack.id
            )
        }
        .alert(
            "Can't play this track",
            isPresented: Binding(
                get: { viewModel.loadError != nil },
                set: { if !$0 { viewModel.loadError = nil } }
            ),
            actions: { Button("OK", role: .cancel) { viewModel.loadError = nil } },
            message: { Text(viewModel.loadError ?? "") }
        )
    }

    // MARK: - Background

    private var ambientGlow: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [preset.toColor.opacity(0.18), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: 230
                )
            )
            .frame(width: 460, height: 460)
            .blur(radius: 8)
            .offset(y: -260)
            .allowsHitTesting(false)
            .animation(.easeInOut(duration: 0.5), value: preset.id)
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            iconButton(systemName: "chevron.down", action: { showPresetSelector = true })
                .accessibilityLabel("Choose preset")
            Spacer()
            VStack(spacing: 2) {
                Text("SPATIAL AUDIO")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(1.6)
                    .foregroundStyle(.white.opacity(0.45))
                Text(albumLine)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(1)
            }
            Spacer()
            HStack(spacing: 2) {
                iconButton(systemName: "music.note.list", action: { showLibrary = true })
                    .accessibilityLabel("Browse library")
                iconButton(systemName: "magnifyingglass", action: { showSearch = true })
                    .accessibilityLabel("Search online music")
            }
        }
        .frame(height: 44)
    }

    private func makeBrowserViewModel() -> MusicBrowserViewModel {
        let browser = MusicBrowserViewModel()
        browser.onPlay = { track, queue in viewModel.play(track, in: queue) }
        return browser
    }

    private var albumLine: String {
        viewModel.currentTrack.albumTitle.isEmpty ? "SoundStage" : viewModel.currentTrack.albumTitle
    }

    private func iconButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(ScaleButtonStyle(pressedScale: 0.9))
    }

    // MARK: - Album art

    private var albumArt: some View {
        ArtworkView(track: viewModel.currentTrack, cornerRadius: 18, placeholderIconSize: 64)
            .frame(maxWidth: 286)
            .aspectRatio(1, contentMode: .fit)
            .shadow(color: preset.toColor.opacity(0.45), radius: 44, y: 24)
            .shadow(color: .black.opacity(0.55), radius: 30, y: 8)
            .animation(.easeInOut(duration: 0.5), value: preset.id)
    }

    // MARK: - Preset pill

    private var presetPill: some View {
        Button { showPresetSelector = true } label: {
            HStack(spacing: 8) {
                SpatialIcon(color: .white)
                    .frame(width: 16, height: 16)
                Text(preset.label)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Rectangle()
                    .fill(.white.opacity(0.35))
                    .frame(width: 1, height: 14)
                    .padding(.horizontal, 2)
                Text("Change")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(.vertical, 8)
            .padding(.leading, 12)
            .padding(.trailing, 16)
            .background(Capsule().fill(preset.gradient()))
            .shadow(color: preset.toColor.opacity(0.4), radius: 12, y: 4)
        }
        .buttonStyle(ScaleButtonStyle(pressedScale: 0.95))
        .accessibilityLabel("Preset: \(preset.label). Change")
    }

    // MARK: - Track info

    private var trackInfo: some View {
        VStack(spacing: 5) {
            Text(viewModel.currentTrack.title)
                .font(.system(size: 25, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
            Text(viewModel.currentTrack.artist)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.4))
                .lineLimit(1)
        }
        .multilineTextAlignment(.center)
    }

    // MARK: - Waveform

    private var waveformSection: some View {
        VStack(spacing: 8) {
            WaveformView(
                preset: preset,
                progress: viewModel.progress,
                isPlaying: viewModel.isPlaying,
                onScrub: { fraction in
                    viewModel.beginSeeking()
                    viewModel.scrub(toFraction: fraction)
                },
                onScrubEnded: { viewModel.endSeeking() }
            )
            .frame(height: 56)

            HStack {
                Text(timeString(viewModel.elapsed))
                Spacer()
                Text("-\(timeString(max(0, viewModel.duration - viewModel.elapsed)))")
            }
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.4))
            .monospacedDigit()
        }
    }

    // MARK: - Transport

    private var transportControls: some View {
        HStack {
            ctrlButton(systemName: "shuffle", size: 20,
                       color: shuffle ? preset.toColor : .white.opacity(0.7),
                       diameter: 44) { shuffle.toggle() }
                .accessibilityLabel("Shuffle")

            Spacer()

            ctrlButton(systemName: "backward.fill", size: 24,
                       color: viewModel.canGoPrevious ? .white : .white.opacity(0.35),
                       diameter: 50, enabled: viewModel.canGoPrevious) { viewModel.previous() }
                .accessibilityLabel("Previous")

            Spacer()

            Button {
                if viewModel.hasTrack {
                    viewModel.togglePlayback()
                } else {
                    showLibrary = true
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(preset.gradient())
                        .frame(width: 68, height: 68)
                        .shadow(color: preset.toColor.opacity(0.5), radius: 22, y: 8)
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundStyle(.white)
                    }
                }
            }
            .buttonStyle(ScaleButtonStyle(pressedScale: 0.92))
            .accessibilityLabel(viewModel.hasTrack ? (viewModel.isPlaying ? "Pause" : "Play") : "Choose a track")

            Spacer()

            ctrlButton(systemName: "forward.fill", size: 24,
                       color: viewModel.canGoNext ? .white : .white.opacity(0.35),
                       diameter: 50, enabled: viewModel.canGoNext) { viewModel.next() }
                .accessibilityLabel("Next")

            Spacer()

            ctrlButton(systemName: "repeat", size: 20,
                       color: repeatOn ? preset.toColor : .white.opacity(0.7),
                       diameter: 44) { repeatOn.toggle() }
                .accessibilityLabel("Repeat")
        }
    }

    private var rotationControl: some View {
        HStack(spacing: 12) {
            Text("16D")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(viewModel.rotationAmount > 0 ? preset.toColor : .white.opacity(0.4))
                .frame(width: 34, alignment: .leading)
            Slider(
                value: Binding(
                    get: { viewModel.rotationAmount },
                    set: { viewModel.setRotation(amount: $0) }
                ),
                in: 0...1
            )
            .tint(preset.toColor)
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 13))
                .foregroundStyle(viewModel.rotationAmount > 0 ? preset.toColor : .white.opacity(0.35))
        }
        .padding(.horizontal, DesignTokens.Spacing.m)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("16D spin")
    }

    private func ctrlButton(systemName: String, size: CGFloat, color: Color, diameter: CGFloat, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size, weight: .medium))
                .foregroundStyle(color)
                .frame(width: diameter, height: diameter)
                .contentShape(Circle())
        }
        .buttonStyle(ScaleButtonStyle(pressedScale: 0.9))
        .disabled(!enabled)
    }

    private func timeString(_ time: TimeInterval) -> String {
        guard time.isFinite, time > 0 else { return "0:00" }
        let total = Int(time.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

#Preview {
    let store = PresetStore()
    NowPlayingView(viewModel: NowPlayingViewModel(presetStore: store))
        .environment(store)
        .environment(ArtworkLoader())
}
