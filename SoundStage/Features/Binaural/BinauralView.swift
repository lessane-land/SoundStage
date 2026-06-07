import SwiftUI

/// Binaural-beats + ambient-soundscape + spatial-audio generator.
struct BinauralView: View {
    @State var viewModel: BinauralViewModel

    private var state: BinauralState { viewModel.current }

    var body: some View {
        ZStack {
            DesignTokens.Palette.backgroundPrimary.ignoresSafeArea()
            ambientGlow

            VStack(spacing: 0) {
                header
                Spacer(minLength: 8)
                orb
                Spacer(minLength: 8)
                info.padding(.top, 10)
                ambienceRow.padding(.top, 16)
                sliders.padding(.top, 14)
                playButton.padding(.top, 16)
                statePicker.padding(.top, 16)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
        }
        .preferredColorScheme(.dark)
        .animation(.easeInOut(duration: 0.5), value: state.id)
    }

    private var ambientGlow: some View {
        Circle()
            .fill(RadialGradient(colors: [state.toColor.opacity(0.22), .clear], center: .center, startRadius: 0, endRadius: 260))
            .frame(width: 520, height: 520)
            .blur(radius: 10)
            .offset(y: -130)
            .allowsHitTesting(false)
    }

    private var header: some View {
        VStack(spacing: 3) {
            Text("BINAURAL · SPATIAL")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(2)
                .foregroundStyle(state.toColor.opacity(0.9))
            Text("Use headphones — both ears needed")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.4))
        }
        .padding(.top, 10)
    }

    // MARK: - Orb

    private var orb: some View {
        TimelineView(.animation(paused: !viewModel.isPlaying)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let pulse = viewModel.isPlaying ? (0.5 + 0.5 * sin(t * 2 * .pi * 0.4)) : 0.5
            let orbit = t * 2 * .pi * (viewModel.spatialAmount * 0.2)
            ZStack {
                Circle()
                    .fill(state.gradient)
                    .frame(width: 184, height: 184)
                    .shadow(color: state.toColor.opacity(0.5), radius: 44 + 18 * pulse)
                    .scaleEffect(1 + 0.03 * pulse)
                    .overlay(Circle().stroke(.white.opacity(0.12), lineWidth: 1))

                if viewModel.isPlaying && viewModel.spatialAmount > 0.01 {
                    Circle()
                        .fill(.white)
                        .frame(width: 10, height: 10)
                        .shadow(color: state.toColor, radius: 8)
                        .offset(x: 120 * cos(orbit), y: 120 * sin(orbit))
                }

                VStack(spacing: 2) {
                    Text(beatText)
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                    Text(state.band.uppercased())
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .frame(height: 250)
        }
    }

    private var beatText: String {
        String(format: viewModel.beatHz < 10 ? "%.1f Hz" : "%.0f Hz", viewModel.beatHz)
    }

    private var info: some View {
        VStack(spacing: 4) {
            Text(state.name)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(state.detail)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.45))
        }
    }

    // MARK: - Ambience

    private var ambienceRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Ambience.allCases) { item in
                    let on = viewModel.ambience == item
                    Button { viewModel.toggleAmbience(item) } label: {
                        HStack(spacing: 6) {
                            Image(systemName: item.icon)
                                .font(.system(size: 13, weight: .semibold))
                            Text(item.rawValue)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(on ? AnyShapeStyle(state.gradient) : AnyShapeStyle(DesignTokens.Palette.cardFill))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(.white.opacity(on ? 0 : 0.07), lineWidth: 1)
                        )
                        .shadow(color: on ? state.toColor.opacity(0.4) : .clear, radius: 10)
                    }
                    .buttonStyle(ScaleButtonStyle(pressedScale: 0.95))
                }
            }
            .padding(.horizontal, 2)
        }
    }

    // MARK: - Sliders

    private var sliders: some View {
        VStack(spacing: 12) {
            tuneRow(label: "BEAT", value: beatText,
                    binding: Binding(get: { viewModel.beatHz }, set: { viewModel.setBeat($0) }), range: 1...30)
            tuneRow(label: "TONE", value: "\(Int(viewModel.carrierHz)) Hz",
                    binding: Binding(get: { viewModel.carrierHz }, set: { viewModel.setCarrier($0) }), range: 80...320)
            tuneRow(label: "AMBIENCE", value: "\(Int(viewModel.ambienceLevel * 100))%",
                    binding: Binding(get: { viewModel.ambienceLevel }, set: { viewModel.setAmbienceLevel($0) }), range: 0...1)
            tuneRow(label: "SPATIAL", value: viewModel.spatialAmount > 0 ? "\(Int(viewModel.spatialAmount * 100))%" : "Off",
                    binding: Binding(get: { viewModel.spatialAmount }, set: { viewModel.setSpatial($0) }), range: 0...1)
        }
    }

    private func tuneRow(label: String, value: String, binding: Binding<Double>, range: ClosedRange<Double>) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
                .frame(width: 74, alignment: .leading)
            Slider(value: binding, in: range)
                .tint(state.toColor)
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
                .monospacedDigit()
                .frame(width: 48, alignment: .trailing)
        }
    }

    // MARK: - Play + states

    private var playButton: some View {
        Button { viewModel.togglePlay() } label: {
            ZStack {
                Circle()
                    .fill(state.gradient)
                    .frame(width: 72, height: 72)
                    .shadow(color: state.toColor.opacity(0.5), radius: 22, y: 8)
                Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(ScaleButtonStyle(pressedScale: 0.92))
        .accessibilityLabel(viewModel.isPlaying ? "Pause" : "Play")
    }

    private var statePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(viewModel.states) { item in
                    Button { viewModel.select(item) } label: {
                        VStack(spacing: 2) {
                            Text(item.name)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                            Text(item.band)
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(item.id == state.id ? AnyShapeStyle(item.gradient) : AnyShapeStyle(DesignTokens.Palette.cardFill))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(.white.opacity(item.id == state.id ? 0 : 0.07), lineWidth: 1)
                        )
                    }
                    .buttonStyle(ScaleButtonStyle(pressedScale: 0.96))
                }
            }
            .padding(.horizontal, 2)
        }
    }
}

#Preview {
    BinauralView(viewModel: BinauralViewModel())
}
