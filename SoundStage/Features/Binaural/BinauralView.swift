import SwiftUI

/// Binaural-beats + ambient-soundscape + spatial-audio generator, matching the
/// SoundStage Focus design.
struct BinauralView: View {
    @State var viewModel: BinauralViewModel
    @State private var showTimer = false

    private var state: BinauralState { viewModel.current }

    private let sliderColumns = [
        GridItem(.flexible(), spacing: 22),
        GridItem(.flexible(), spacing: 22)
    ]

    var body: some View {
        ZStack {
            DesignTokens.Palette.backgroundPrimary.ignoresSafeArea()
            topWash

            VStack(spacing: 0) {
                header
                ZStack {
                    BinauralAmbientLayer(soundscapes: viewModel.activeAmbiences, color: state.toColor,
                                         intensity: viewModel.ambienceLevel, isPlaying: viewModel.isPlaying)
                    BinauralOrb(state: state, beatHz: viewModel.beatHz, spatial: viewModel.spatialAmount, isPlaying: viewModel.isPlaying)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 300)
                .padding(.top, 4)
                nameAndDesc
                Spacer(minLength: 6)
                ambienceChips.padding(.top, 8)
                sliders.padding(.top, 14)
                playButton.padding(.top, 18)
                statePills.padding(.top, 16)
            }
            .padding(.bottom, 10)
        }
        .preferredColorScheme(.dark)
        .animation(.easeInOut(duration: 0.5), value: state.id)
        .fullScreenCover(isPresented: $showTimer) {
            BinauralTimerView(state: state, viewModel: viewModel)
        }
    }

    private var topWash: some View {
        RadialGradient(colors: [state.toColor.opacity(0.15), .clear], center: .init(x: 0.5, y: -0.05), startRadius: 0, endRadius: 340)
            .ignoresSafeArea()
            .allowsHitTesting(false)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("BINAURAL · SPATIAL")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(state.toColor)
                HStack(spacing: 6) {
                    Image(systemName: "headphones")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Use headphones")
                        .font(.system(size: 12.5, weight: .medium, design: .rounded))
                }
                .foregroundStyle(.white.opacity(0.45))
            }
            Spacer()
            Button { showTimer = true } label: {
                Image(systemName: "timer")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(.white.opacity(0.05)))
                    .overlay(Circle().stroke(.white.opacity(0.1), lineWidth: 1))
            }
            .accessibilityLabel("Session timer")
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
    }

    private var nameAndDesc: some View {
        VStack(spacing: 3) {
            Text(state.name)
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            Text(state.detail)
                .font(.system(size: 14.5, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.45))
        }
    }

    private var ambienceChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 9) {
                ForEach(Ambience.allCases) { item in
                    let on = viewModel.isActive(item)
                    Button { viewModel.toggleAmbience(item) } label: {
                        HStack(spacing: 7) {
                            Image(systemName: item.icon)
                                .font(.system(size: 14, weight: .semibold))
                            Text(item.label)
                                .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(on ? .white : .white.opacity(0.55))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .fill(on ? AnyShapeStyle(state.gradient.opacity(0.2)) : AnyShapeStyle(.white.opacity(0.04)))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .stroke(on ? state.toColor : .white.opacity(0.1), lineWidth: 1)
                        )
                        .shadow(color: on ? state.toColor.opacity(0.3) : .clear, radius: 12)
                    }
                    .buttonStyle(ScaleButtonStyle(pressedScale: 0.95))
                }
            }
            .padding(.horizontal, 24)
        }
    }

    private var sliders: some View {
        LazyVGrid(columns: sliderColumns, spacing: 16) {
            BinauralSlider(state: state, label: "BEAT", valueText: beatText,
                           value: Binding(get: { (viewModel.beatHz - 1) / 39 }, set: { viewModel.setBeat(1 + $0 * 39) }))
            BinauralSlider(state: state, label: "TONE", valueText: "\(Int(viewModel.carrierHz)) Hz",
                           value: Binding(get: { (viewModel.carrierHz - 55) / 100 }, set: { viewModel.setCarrier(55 + $0 * 100) }))
            BinauralSlider(state: state, label: "AMBIENCE", valueText: "\(Int(viewModel.ambienceLevel * 100))%",
                           value: Binding(get: { viewModel.ambienceLevel }, set: { viewModel.setAmbienceLevel($0) }))
            BinauralSlider(state: state, label: "SPATIAL", valueText: viewModel.spatialAmount < 0.04 ? "Off" : "\(Int(viewModel.spatialAmount * 100))%",
                           value: Binding(get: { viewModel.spatialAmount }, set: { viewModel.setSpatial($0) }))
        }
        .padding(.horizontal, 24)
    }

    private var beatText: String {
        viewModel.beatHz.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(viewModel.beatHz)) Hz" : String(format: "%.1f Hz", viewModel.beatHz)
    }

    private var playButton: some View {
        Button { viewModel.togglePlay() } label: {
            ZStack {
                Circle()
                    .fill(state.gradient)
                    .frame(width: 76, height: 76)
                    .shadow(color: state.toColor.opacity(0.5), radius: 24, y: 8)
                    .overlay(
                        Circle().fill(LinearGradient(colors: [.white.opacity(0.3), .clear], startPoint: .top, endPoint: .center))
                    )
                Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(ScaleButtonStyle(pressedScale: 0.93))
        .accessibilityLabel(viewModel.isPlaying ? "Pause" : "Play")
    }

    private var statePills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(viewModel.states) { item in
                    let on = item.id == state.id
                    Button { viewModel.select(item) } label: {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.name)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(on ? .white : .white.opacity(0.8))
                            Text("\(item.band.uppercased()) · \(hzLabel(item.beatHz))HZ")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .tracking(1.2)
                                .foregroundStyle(.white.opacity(on ? 0.8 : 0.35))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(
                            Capsule().fill(on ? AnyShapeStyle(item.gradient) : AnyShapeStyle(.white.opacity(0.04)))
                        )
                        .overlay(Capsule().stroke(.white.opacity(on ? 0 : 0.12), lineWidth: 1))
                        .shadow(color: on ? item.toColor.opacity(0.35) : .clear, radius: 14)
                    }
                    .buttonStyle(ScaleButtonStyle(pressedScale: 0.96))
                }
            }
            .padding(.horizontal, 24)
        }
    }

    private func hzLabel(_ hz: Double) -> String {
        hz.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(hz))" : String(format: "%.1f", hz)
    }
}

#Preview {
    BinauralView(viewModel: BinauralViewModel())
}
