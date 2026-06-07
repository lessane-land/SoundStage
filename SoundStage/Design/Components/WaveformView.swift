import SwiftUI

/// A stylized bar waveform for the now-playing screen.
///
/// Phase 1 renders a deterministic, decorative pattern (no real sample
/// analysis yet). When `isAnimating` is true the bars breathe gently to signal
/// active playback. A future phase can drive `samples` from a real tap.
struct WaveformView: View {
    var samples: [CGFloat]
    var isAnimating: Bool

    @State private var phase: CGFloat = 0

    init(samples: [CGFloat]? = nil, isAnimating: Bool = false) {
        self.samples = samples ?? WaveformView.defaultSamples
        self.isAnimating = isAnimating
    }

    var body: some View {
        GeometryReader { proxy in
            let count = samples.count
            let spacing = DesignTokens.Spacing.xs
            let barWidth = max(2, (proxy.size.width - spacing * CGFloat(count - 1)) / CGFloat(count))

            HStack(alignment: .center, spacing: spacing) {
                ForEach(Array(samples.enumerated()), id: \.offset) { index, sample in
                    Capsule()
                        .fill(barColor(for: index, count: count))
                        .frame(width: barWidth, height: height(for: sample))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .onAppear { if isAnimating { startAnimating() } }
        .onChange(of: isAnimating) { _, newValue in
            if newValue { startAnimating() }
        }
        .accessibilityHidden(true)
    }

    private func height(for sample: CGFloat) -> CGFloat {
        let base: CGFloat = 12
        let span: CGFloat = 64
        let wobble = isAnimating ? (sin(phase + sample * 6) + 1) / 2 * 0.35 : 0
        return base + span * (sample * (0.65 + wobble))
    }

    private func barColor(for index: Int, count: Int) -> Color {
        let t = Double(index) / Double(max(1, count - 1))
        return DesignTokens.Palette.accent.opacity(0.55 + 0.45 * (1 - abs(t - 0.5) * 2))
    }

    private func startAnimating() {
        withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
            phase = .pi * 2
        }
    }

    static let defaultSamples: [CGFloat] = [
        0.2, 0.45, 0.7, 0.5, 0.85, 0.6, 0.95, 0.55, 0.75, 0.4,
        0.6, 0.9, 0.5, 0.7, 0.35, 0.8, 0.5, 0.65, 0.3, 0.55
    ]
}

#Preview {
    WaveformView(isAnimating: true)
        .frame(height: 120)
        .padding()
        .background(DesignTokens.Palette.backgroundPrimary)
}
