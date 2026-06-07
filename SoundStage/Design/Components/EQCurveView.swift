import SwiftUI

/// Draws a smooth EQ response curve from a set of `EQBand` values.
///
/// This is a perceptual sketch of the preset's tonal shape, not a precise
/// transfer function: each band contributes a Gaussian bump/dip on a log
/// frequency axis and the contributions are summed. Used as a small preview on
/// preset cards and a larger readout on the player.
struct EQCurveView: View {
    var bands: [EQBand]
    var lineColor: Color = DesignTokens.Palette.accent
    var lineWidth: CGFloat = 2

    // Frequency range plotted, in Hz (log scale).
    private let minFrequency: Float = 30
    private let maxFrequency: Float = 18_000
    private let maxGain: Float = 8  // dB at the vertical extremes

    var body: some View {
        Canvas { context, size in
            let path = curvePath(in: size)

            // Soft fill under the curve.
            var fill = path
            fill.addLine(to: CGPoint(x: size.width, y: size.height))
            fill.addLine(to: CGPoint(x: 0, y: size.height))
            fill.closeSubpath()
            context.fill(
                fill,
                with: .linearGradient(
                    Gradient(colors: [lineColor.opacity(0.25), .clear]),
                    startPoint: CGPoint(x: 0, y: 0),
                    endPoint: CGPoint(x: 0, y: size.height)
                )
            )

            context.stroke(path, with: .color(lineColor), lineWidth: lineWidth)
        }
        .accessibilityHidden(true)
    }

    private func curvePath(in size: CGSize) -> Path {
        var path = Path()
        let steps = max(2, Int(size.width))
        for step in 0...steps {
            let x = CGFloat(step) / CGFloat(steps)
            let freq = frequency(atNormalizedX: Float(x))
            let gain = totalGain(at: freq)
            let y = yPosition(forGain: gain, height: size.height)
            let point = CGPoint(x: x * size.width, y: y)
            if step == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        return path
    }

    /// Map a normalized x (0...1) to a frequency on a log scale.
    private func frequency(atNormalizedX x: Float) -> Float {
        let logMin = log10(minFrequency)
        let logMax = log10(maxFrequency)
        return pow(10, logMin + (logMax - logMin) * x)
    }

    /// Sum each band's contribution at a given frequency.
    private func totalGain(at frequency: Float) -> Float {
        var gain: Float = 0
        let octaveSpread: Float = log10(maxFrequency) - log10(minFrequency)
        for band in bands {
            let distance = (log10(frequency) - log10(band.frequency)) / (octaveSpread * 0.18 * band.bandwidth)
            gain += band.gain * exp(-distance * distance)
        }
        return gain
    }

    private func yPosition(forGain gain: Float, height: CGFloat) -> CGFloat {
        let normalized = max(-1, min(1, gain / maxGain)) // -1...1
        let mid = height / 2
        return mid - CGFloat(normalized) * (height / 2 - 4)
    }
}

#Preview {
    EQCurveView(bands: [
        EQBand(frequency: 60, gain: 5, bandwidth: 1.2, filterType: .lowShelf),
        EQBand(frequency: 1_000, gain: -3, bandwidth: 1.0),
        EQBand(frequency: 9_000, gain: 4, bandwidth: 1.1, filterType: .highShelf)
    ])
    .frame(height: 120)
    .padding()
    .background(DesignTokens.Palette.backgroundPrimary)
}
