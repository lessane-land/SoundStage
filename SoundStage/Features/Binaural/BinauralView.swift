import SwiftUI

/// Binaural-beats generator: pick a state, play, and tune the tone/beat live.
struct BinauralView: View {
    @State var viewModel: BinauralViewModel

    private var state: BinauralState { viewModel.current }

    var body: some View {
        ZStack {
            DesignTokens.Palette.backgroundPrimary.ignoresSafeArea()
            ambientGlow

            VStack(spacing: 0) {
                header
                Spacer(minLength: 12)
                orb
                Spacer(minLength: 12)
                info
                sliders
                    .padding(.top, 20)
                playButton
                    .padding(.top, 22)
                statePicker
                    .padding(.top, 24)
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
            .offset(y: -120)
            .allowsHitTesting(false)
    }

    private var header: some View {
        VStack(spacing: 3) {
            Text("BINAURAL")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(2)
                .foregroundStyle(state.toColor.opacity(0.9))
            Text("Use headphones — both ears needed")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.4))
        }
        .padding(.top, 12)
    }

    // MARK: - Orb

    private var orb: some View {
        TimelineView(.animation(paused: !viewModel.isPlaying)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let pulse = viewModel.isPlaying ? (0.5 + 0.5 * sin(t * 2 * .pi * 0.4)) : 0.5
            ZStack {
                Circle()
                    .fill(state.gradient)
                    .frame(width: 220, height: 220)
                    .shadow(color: state.toColor.opacity(0.5), radius: 50 + 20 * pulse)
                    .scaleEffect(1 + 0.03 * pulse)
                    .overlay(
                        Circle().stroke(.white.opacity(0.12), lineWidth: 1)
                    )
                VStack(spacing: 2) {
                    Text(beatText)
                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                    Text(state.band.uppercased())
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
        }
    }

    private var beatText: String {
        String(format: viewModel.beatHz < 10 ? "%.1f Hz" : "%.0f Hz", viewModel.beatHz)
    }

    private var info: some View {
        VStack(spacing: 5) {
            Text(state.name)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(state.detail)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.45))
        }
    }

    // MARK: - Sliders

    private var sliders: some View {
        VStack(spacing: 16) {
            tuneRow(label: "BEAT", value: beatText,
                    binding: Binding(get: { viewModel.beatHz }, set: { viewModel.setBeat($0) }),
                    range: 1...30)
            tuneRow(label: "TONE", value: "\(Int(viewModel.carrierHz)) Hz",
                    binding: Binding(get: { viewModel.carrierHz }, set: { viewModel.setCarrier($0) }),
                    range: 80...320)
        }
    }

    private func tuneRow(label: String, value: String, binding: Binding<Double>, range: ClosedRange<Double>) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .tracking(0.5)
                .foregroundStyle(.white.opacity(0.5))
                .frame(width: 42, alignment: .leading)
            Slider(value: binding, in: range)
                .tint(state.toColor)
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
                .monospacedDigit()
                .frame(width: 58, alignment: .trailing)
        }
    }

    // MARK: - Play

    private var playButton: some View {
        Button { viewModel.togglePlay() } label: {
            ZStack {
                Circle()
                    .fill(state.gradient)
                    .frame(width: 76, height: 76)
                    .shadow(color: state.toColor.opacity(0.5), radius: 24, y: 8)
                Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(ScaleButtonStyle(pressedScale: 0.92))
        .accessibilityLabel(viewModel.isPlaying ? "Pause" : "Play")
    }

    // MARK: - State picker

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
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(item.id == state.id ? AnyShapeStyle(item.gradient.opacity(0.9)) : AnyShapeStyle(DesignTokens.Palette.cardFill))
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
