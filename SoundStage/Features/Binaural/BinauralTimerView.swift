import SwiftUI
import Combine

/// Session timer: a gradient countdown ring with duration presets, matching the
/// design. Starting a session ensures playback; finishing stops it.
struct BinauralTimerView: View {
    let state: BinauralState
    let viewModel: BinauralViewModel

    @Environment(\.dismiss) private var dismiss

    private static let presets: [(label: String, seconds: Int?)] = [
        ("15", 15 * 60), ("30", 30 * 60), ("60", 60 * 60), ("\u{221E}", nil)
    ]

    @State private var presetIndex = 1
    @State private var remaining = 30 * 60
    @State private var running = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            DesignTokens.Palette.backgroundPrimary.ignoresSafeArea()
            RadialGradient(colors: [state.toColor.opacity(0.12), .clear], center: .init(x: 0.5, y: 0.3), startRadius: 0, endRadius: 320)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                ring.padding(.top, 56)
                presetRow.padding(.top, 44)
                Spacer()
                startStop.padding(.bottom, 44)
            }
            .padding(.horizontal, 24)
        }
        .preferredColorScheme(.dark)
        .onDisappear { stop() }
        .onReceive(timer) { _ in
            guard running, !isInfinite else { return }
            remaining = max(0, remaining - 1)
            if remaining == 0 { finish() }
        }
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
        .frame(width: 280, height: 280)
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
                        .frame(width: 60, height: 60)
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

    private func start() {
        running = true
        viewModel.setPlaying(true)
    }

    private func stop() {
        running = false
    }

    private func finish() {
        stop()
        viewModel.setPlaying(false)
    }
}
