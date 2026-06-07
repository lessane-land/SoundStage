import SwiftUI
import Combine

/// Session timer: a gradient countdown ring with duration presets, an optional
/// sleep fade-out and an end chime — matching the design's `TimerScreen`.
struct BinauralTimerView: View {
    let state: BinauralState
    @Bindable var viewModel: BinauralViewModel

    @Environment(\.dismiss) private var dismiss

    private static let presets: [(label: String, seconds: Int?)] = [
        ("15", 15 * 60), ("30", 30 * 60), ("60", 60 * 60), ("\u{221E}", nil)
    ]

    @State private var presetIndex = 1
    @State private var remaining = 30 * 60
    @State private var running = false
    @State private var fadeOut = true
    @State private var fadeLen = 0.4   // normalized over 1...15 min

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var fadeMinutes: Int { Int((1 + fadeLen * 14).rounded()) }

    var body: some View {
        ZStack {
            DesignTokens.Palette.backgroundPrimary.ignoresSafeArea()
            RadialGradient(colors: [state.toColor.opacity(0.12), .clear], center: .init(x: 0.5, y: 0.3), startRadius: 0, endRadius: 320)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        ring.padding(.top, 28)
                        presetRow.padding(.top, 32)
                        options.padding(.top, 24)
                    }
                }
                startStop.padding(.top, 8).padding(.bottom, 36)
            }
            .padding(.horizontal, 24)
        }
        .preferredColorScheme(.dark)
        .onDisappear { stop() }
        .onReceive(timer) { _ in tick() }
    }

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(.white.opacity(0.08)))
            }
            Spacer()
            Text("SESSION")
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .tracking(2)
                .foregroundStyle(state.toColor)
            Spacer()
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.top, 12)
    }

    private var ring: some View {
        ZStack {
            Circle().stroke(.white.opacity(0.08), lineWidth: 12)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(LinearGradient(colors: [state.fromColor, state.toColor], startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: state.toColor.opacity(0.6), radius: 8)
                .animation(.linear(duration: 0.9), value: fraction)
            VStack(spacing: 4) {
                Text(timeText)
                    .font(.system(size: 56, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                Text(running ? "REMAINING" : state.name.uppercased())
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .frame(width: 252, height: 252)
    }

    private var presetRow: some View {
        HStack(spacing: 12) {
            ForEach(Array(Self.presets.enumerated()), id: \.offset) { index, preset in
                let on = index == presetIndex
                Button {
                    presetIndex = index
                    remaining = preset.seconds ?? 0
                } label: {
                    Text(preset.label)
                        .font(.system(size: preset.label == "\u{221E}" ? 24 : 19, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 58, height: 58)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(on ? AnyShapeStyle(state.gradient) : AnyShapeStyle(.white.opacity(0.05)))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(.white.opacity(on ? 0 : 0.12), lineWidth: 1)
                        )
                        .shadow(color: on ? state.toColor.opacity(0.4) : .clear, radius: 12)
                }
                .buttonStyle(ScaleButtonStyle(pressedScale: 0.95))
            }
        }
    }

    private var options: some View {
        VStack(spacing: 10) {
            BinauralGlassToggle(state: state, label: "Fade out",
                                sub: "Gently lower volume over the last \(fadeMinutes) min",
                                icon: "speaker.wave.1.fill", on: fadeOut, onChange: { fadeOut = $0 })
            if fadeOut {
                BinauralSlider(state: state, label: "FADE LENGTH", valueText: "\(fadeMinutes) min",
                               value: $fadeLen)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 2)
            }
            BinauralGlassToggle(state: state, label: "Chime at end",
                                sub: "Soft bell when the session completes",
                                icon: "bell.fill", on: viewModel.chime, onChange: { viewModel.chime = $0 })
        }
    }

    private var startStop: some View {
        Button { running ? stop() : start() } label: {
            HStack(spacing: 10) {
                Image(systemName: running ? "stop.fill" : "play.fill")
                    .font(.system(size: 16, weight: .bold))
                Text(running ? "Stop Session" : "Start Session")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 44)
            .frame(height: 60)
            .background(
                Capsule().fill(running ? AnyShapeStyle(.white.opacity(0.1)) : AnyShapeStyle(state.gradient))
            )
            .shadow(color: running ? .clear : state.toColor.opacity(0.45), radius: 18, y: 6)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Logic

    private var isInfinite: Bool { Self.presets[presetIndex].seconds == nil }

    private var fraction: CGFloat {
        guard let total = Self.presets[presetIndex].seconds, total > 0 else { return 1 }
        return max(0, CGFloat(remaining) / CGFloat(total))
    }

    private var timeText: String {
        if isInfinite { return "\u{221E}" }
        return "\(remaining / 60):\(String(format: "%02d", remaining % 60))"
    }

    private func tick() {
        guard running, !isInfinite else { return }
        remaining = max(0, remaining - 1)
        applyFade()
        if remaining == 0 { finish() }
    }

    private func applyFade() {
        guard fadeOut else { return }
        let window = fadeMinutes * 60
        if remaining <= window, window > 0 {
            viewModel.applyFade(Double(remaining) / Double(window))
        } else {
            viewModel.restoreVolume()
        }
    }

    private func start() {
        if remaining == 0, let total = Self.presets[presetIndex].seconds { remaining = total }
        running = true
        viewModel.restoreVolume()
        viewModel.setPlaying(true)
    }

    private func stop() {
        running = false
        viewModel.restoreVolume()
    }

    private func finish() {
        running = false
        viewModel.setPlaying(false)
        viewModel.restoreVolume()
        viewModel.ringChime()
    }
}
