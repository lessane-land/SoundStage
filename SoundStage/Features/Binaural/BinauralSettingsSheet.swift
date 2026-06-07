import SwiftUI

/// Settings ("More"): master volume, mute, session chime, headphones note.
struct BinauralSettingsSheet: View {
    @Bindable var viewModel: BinauralViewModel
    let state: BinauralState

    var body: some View {
        ZStack {
            BinauralSheetBackground()
            VStack(spacing: 0) {
                BinauralSheetHeader(state: state, eyebrow: "MORE", title: "Settings")
                ScrollView {
                    VStack(spacing: 14) {
                        toneCard
                        volumeCard
                        BinauralGlassToggle(state: state, label: "Mute", sub: "Silence all output",
                                            icon: "speaker.slash.fill", on: viewModel.muted,
                                            onChange: { viewModel.setMuted($0) })
                        BinauralGlassToggle(state: state, label: "Chime at end", sub: "Soft bell when a session completes",
                                            icon: "bell.fill", on: viewModel.chime,
                                            onChange: { viewModel.chime = $0 })
                        headphonesNote
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var toneCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "waveform")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(viewModel.toneLevel <= 0.001 ? .white.opacity(0.4) : state.toColor)
                Text("BINAURAL TONE")
                    .font(.system(size: 11.5, weight: .bold, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
                Text(viewModel.toneLevel <= 0.001 ? "Off" : "\(Int(viewModel.toneLevel * 100))%")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            BinauralMiniSlider(
                state: state,
                value: Binding(get: { viewModel.toneLevel }, set: { viewModel.setToneLevel($0) })
            )
            Text("The brainwave beat. Lower it (or turn it off) if it feels intense — the soundscapes still play.")
                .font(.system(size: 11.5, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.4))
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var volumeCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: viewModel.muted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(viewModel.muted ? .white.opacity(0.4) : state.toColor)
                Text("MASTER VOLUME")
                    .font(.system(size: 11.5, weight: .bold, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
                Text(viewModel.muted ? "Muted" : "\(Int(viewModel.volume * 100))%")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            BinauralMiniSlider(
                state: state,
                value: Binding(get: { viewModel.volume }, set: { viewModel.setVolume($0) })
            )
            .opacity(viewModel.muted ? 0.4 : 1)
            .allowsHitTesting(!viewModel.muted)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var headphonesNote: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Image(systemName: "headphones")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
                Text("Use headphones")
                    .font(.system(size: 13.5, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
            }
            Text("Binaural beats rely on a slightly different tone in each ear. Headphones are required for the spatial and brainwave effect. Not a substitute for medical care.")
                .font(.system(size: 12.5, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.4))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.06), lineWidth: 1)
        )
    }
}
