import SwiftUI

/// Animated frequency curve that pulses with playback — a filled gradient under
/// a smooth, glowing line in the preset's colors. Decorative.
struct EQSpectrumView: View {
    let preset: Preset
    var isPlaying: Bool

    private let bandCount = 7

    var body: some View {
        TimelineView(.animation(paused: !isPlaying)) { timeline in
            Canvas { context, size in
                draw(context: context, size: size,
                     time: timeline.date.timeIntervalSinceReferenceDate)
            }
        }
        .accessibilityHidden(true)
    }

    private func draw(context: GraphicsContext, size: CGSize, time: TimeInterval) {
        let amplitude = isPlaying ? 1.0 : 0.35
        var points: [CGPoint] = []
        for i in 0..<bandCount {
            let x = Double(i) / Double(bandCount - 1) * size.width
            let band = 0.5 + 0.5 * sin(time * (1.1 + Double(i) * 0.18) + Double(i) * 1.3)
            let shelf = sin(Double(i) / Double(bandCount - 1) * .pi)
            let y = size.height - (0.18 + amplitude * (0.25 + 0.5 * band * (0.5 + 0.5 * shelf))) * size.height
            points.append(CGPoint(x: x, y: y))
        }

        // Filled area under the curve.
        var fillPath = smoothPath(points)
        fillPath.addLine(to: CGPoint(x: size.width, y: size.height))
        fillPath.addLine(to: CGPoint(x: 0, y: size.height))
        fillPath.closeSubpath()
        context.fill(
            fillPath,
            with: .linearGradient(
                Gradient(colors: [preset.toColor.opacity(0.32), preset.fromColor.opacity(0)]),
                startPoint: .zero,
                endPoint: CGPoint(x: 0, y: size.height)
            )
        )

        // Glowing line.
        let line = smoothPath(points)
        var glow = context
        glow.addFilter(.shadow(color: preset.toColor.opacity(0.7), radius: 6))
        glow.stroke(
            line,
            with: .linearGradient(
                Gradient(colors: [preset.fromColor, preset.toColor]),
                startPoint: .zero,
                endPoint: CGPoint(x: size.width, y: 0)
            ),
            style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
        )
    }

    /// Catmull-Rom → Bézier smoothing through the sample points.
    private func smoothPath(_ points: [CGPoint]) -> Path {
        var path = Path()
        guard points.count > 1 else { return path }
        path.move(to: points[0])
        for i in 0..<(points.count - 1) {
            let p0 = points[i == 0 ? 0 : i - 1]
            let p1 = points[i]
            let p2 = points[i + 1]
            let p3 = i + 2 < points.count ? points[i + 2] : p2
            let cp1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6)
            let cp2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
            path.addCurve(to: p2, control1: cp1, control2: cp2)
        }
        return path
    }
}

#Preview {
    EQSpectrumView(preset: PresetStore().presets[0], isPlaying: true)
        .frame(height: 72)
        .padding()
        .background(DesignTokens.Palette.backgroundPrimary)
}
